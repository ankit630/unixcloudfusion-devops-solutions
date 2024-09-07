#!/bin/bash

set -euo pipefail

# Function to get AWS Account ID
get_aws_account_id() {
    aws sts get-caller-identity --query "Account" --output text
}

# Function to get EKS Cluster Name
get_eks_cluster_name() {
    aws eks list-clusters --query "clusters[0]" --output text
}

# Function to get AWS Region
get_aws_region() {
    aws configure get region
}

# Function to get GitLab URL
get_gitlab_url() {
    echo "https://gitlab.com"
}

# Get variables dynamically
AWS_ACCOUNT_ID=$(get_aws_account_id)
EKS_CLUSTER_NAME=$(get_eks_cluster_name)
AWS_REGION=$(get_aws_region)
GITLAB_URL=$(get_gitlab_url)

# Function to check and install eksctl
ensure_eksctl() {
    if ! command -v eksctl &> /dev/null; then
        echo "eksctl not found. Installing..."
        if [[ "$(uname)" == "Linux" ]]; then
            curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
            sudo mv /tmp/eksctl /usr/local/bin
        elif [[ "$(uname)" == "Darwin" ]]; then
            brew tap weaveworks/tap
            brew install weaveworks/tap/eksctl
        else
            echo "Unsupported operating system. Please install eksctl manually."
            exit 1
        fi
    fi
    echo "eksctl version: $(eksctl version)"
}

# Function to handle AWS Secrets Manager secret
handle_secret() {
    local secret_name="gitlab/gitlab-runner-secrets"
    local new_secret_string="{\"runner-token\":\"$RUNNER_TOKEN\",\"runner-registration-token\":\"\"}"

    if aws secretsmanager describe-secret --secret-id "$secret_name" >/dev/null 2>&1; then
        echo "Secret already exists. Checking if update is needed..."
        local current_secret_string=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --query SecretString --output text)
        if [ "$current_secret_string" != "$new_secret_string" ]; then
            echo "Updating secret..."
            aws secretsmanager update-secret --secret-id "$secret_name" --secret-string "$new_secret_string"
        else
            echo "Secret is up to date. No changes needed."
        fi
    else
        echo "Creating new secret..."
        aws secretsmanager create-secret --name "$secret_name" --description "GitLab Runner secrets" --secret-string "$new_secret_string"
    fi
}

check_requirements() {
    local required_tools=("aws" "kubectl" "helm")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "$tool is not installed. Attempting to install..."
            case $tool in
                aws)
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip awscliv2.zip
                    sudo ./aws/install
                    rm -rf aws awscliv2.zip
                    ;;
                kubectl)
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    sudo mv kubectl /usr/local/bin/
                    ;;
                helm)
                    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                    ;;
            esac
            
            if ! command -v "$tool" &> /dev/null; then
                echo "Error: Failed to install $tool. Please install it manually and try again."
                exit 1
            fi
        fi
    done
    echo "All required tools are installed."
}

# Check for required tools
check_requirements

# Get the OIDC provider URL
OIDC_PROVIDER=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
echo "OIDC Provider: $OIDC_PROVIDER"

# Function to create or update IAM Role using AWS CLI
create_or_update_iam_role() {
    local role_name="GitLabRunnerRole"
    local policy_name="GitLabRunnerPolicy"

    # Check if the role already exists
    if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
        echo "IAM Role $role_name already exists. Updating..."
    else
        echo "Creating IAM Role $role_name..."
        aws iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document file://<(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_PROVIDER}:sub": "system:serviceaccount:gitlab-runner:gitlab-runner-sa",
                    "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF
)
    fi

    # Create or update the inline policy
    echo "Creating or updating inline policy $policy_name for role $role_name..."
    aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        --policy-document file://<(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecrets"
            ],
            "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:gitlab/gitlab-runner-secrets*"
        }
    ]
}
EOF
)

    # Get the role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text)
    echo "Role ARN: $ROLE_ARN"
}

# Function to create or update ServiceAccount using eksctl
create_or_update_service_account() {
    local cluster_name=$1
    local namespace=$2
    local sa_name=$3
    local role_arn=$4

    if kubectl get serviceaccount -n "$namespace" "$sa_name" >/dev/null 2>&1; then
        echo "Updating ServiceAccount $sa_name..."
        eksctl create iamserviceaccount \
            --cluster="$cluster_name" \
            --namespace="$namespace" \
            --name="$sa_name" \
            --attach-role-arn="$role_arn" \
            --override-existing-serviceaccounts \
            --approve
    else
        echo "Creating ServiceAccount $sa_name..."
        eksctl create iamserviceaccount \
            --cluster="$cluster_name" \
            --namespace="$namespace" \
            --name="$sa_name" \
            --attach-role-arn="$role_arn" \
            --approve
    fi
}

# New function to get the EKS node role
get_eks_node_role() {
    local cluster_name=$1
    local nodegroup_name=$(aws eks list-nodegroups --cluster-name "$cluster_name" --query 'nodegroups[0]' --output text)
    local role_arn=$(aws eks describe-nodegroup --cluster-name "$cluster_name" --nodegroup-name "$nodegroup_name" --query 'nodegroup.nodeRole' --output text)
    echo "$role_arn"
}

# New function to update EKS node role with EFS permissions
update_eks_node_role_for_efs() {
    local role_arn=$1
    local role_name=$(echo "$role_arn" | awk -F'/' '{print $NF}')
    local policy_name="EKSNodeEFSPolicy"

    echo "Updating EKS Node Role $role_name with EFS permissions..."
    aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        --policy-document file://<(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticfilesystem:DescribeMountTargets",
                "elasticfilesystem:DescribeFileSystems",
                "elasticfilesystem:DescribeAccessPoints",
                "elasticfilesystem:CreateAccessPoint",
                "elasticfilesystem:DeleteAccessPoint",
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    echo "EFS permissions added to EKS Node Role $role_name"
}

# Prompt user for GitLab Runner token
read -sp "Enter your GitLab Runner token: " RUNNER_TOKEN
echo

# Ensure eksctl is installed
ensure_eksctl

# Handle secret in AWS Secrets Manager
echo "Handling secret in AWS Secrets Manager..."
handle_secret

# Create or update IAM Role using AWS CLI
echo "Creating or updating IAM Role..."
create_or_update_iam_role

# Get EKS node role
EKS_NODE_ROLE=$(get_eks_node_role "$EKS_CLUSTER_NAME")
echo "EKS Node Role: $EKS_NODE_ROLE"

# Update IAM Role with EFS permissions
echo "Updating IAM Role with EFS permissions..."
update_eks_node_role_for_efs


# Create or update ServiceAccount using eksctl
echo "Creating or updating ServiceAccount using eksctl..."
create_or_update_service_account "$EKS_CLUSTER_NAME" "gitlab-runner" "gitlab-runner-sa" "$ROLE_ARN"

# Install EFS CSI Driver
echo "Installing EFS CSI Driver..."
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

sleep 5

# Wait for the driver to be ready
echo "Waiting for EFS CSI Driver to be ready..."
kubectl rollout status deployment efs-csi-controller -n kube-system

# Apply ArgoCD application
echo "Applying ArgoCD application for GitLab Runner..."
kubectl apply -f ../argocd-apps/gitlab-runner-app.yaml

echo "GitLab Runner setup complete!"
echo "ArgoCD will now manage the deployment of GitLab Runner and its resources."