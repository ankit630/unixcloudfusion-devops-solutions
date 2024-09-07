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

echo "Using the following variables:"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "EKS Cluster Name: $EKS_CLUSTER_NAME"
echo "AWS Region: $AWS_REGION"
echo "GitLab URL: $GITLAB_URL"

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

# Function to set up EFS configuration
setup_efs_config() {
    # Fetch the EFS ID based on the Project tag
    EFS_ID=$(aws efs describe-file-systems --query "FileSystems[?Tags[?Key=='Project' && Value=='gitlab-runner']].FileSystemId" --output text)

    if [ -z "$EFS_ID" ]; then
        echo "Error: No EFS file system found with the tag Project=gitlab-runner."
        exit 1
    fi

    # Update the ConfigMap with the EFS ID
    kubectl create configmap efs-config \
        --from-literal=EFS_ID=$EFS_ID \
        -n gitlab-runner \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "ConfigMap updated with EFS ID: $EFS_ID"
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

# Create or update ServiceAccount using eksctl
echo "Creating or updating ServiceAccount using eksctl..."
create_or_update_service_account "$EKS_CLUSTER_NAME" "gitlab-runner" "gitlab-runner-sa" "$ROLE_ARN"

 # Function to wait for PVC to be bound
 wait_for_pvc() {
   local pvc_name="$1"
   local namespace="$2"
   local timeout=300
   local interval=10
   local elapsed=0
 
   while [ $elapsed -lt $timeout ]; do
     status=$(kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
     if [ "$status" = "Bound" ]; then
       echo "PVC $pvc_name is now bound."
       return 0
     fi
     echo "Waiting for PVC $pvc_name to be bound... (${elapsed}s)"
     sleep $interval
     elapsed=$((elapsed + interval))
   done
 
   echo "Timeout waiting for PVC $pvc_name to be bound."
   return 1
 }

# Set up EFS configuration
echo "Setting up EFS configuration..."
setup_efs_config

# Create or update the ConfigMap
kubectl create configmap gitlab-runner-config \
    --from-literal=aws-account-id=$AWS_ACCOUNT_ID \
    --from-literal=role-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitlabRunnerServiceAccountRole" \
    -n gitlab-runner \
    --dry-run=client -o yaml | kubectl apply -f -

echo "ConfigMap created/updated with AWS Account ID: $AWS_ACCOUNT_ID"

# Apply ArgoCD application
echo "Applying ArgoCD application for GitLab Runner..."
kubectl apply -f ../argocd-apps/gitlab-runner-app.yaml

 # Wait for PVC to be bound
 echo "Waiting for PVC to be bound..."
 wait_for_pvc "gitlab-runner-efs-pvc" "gitlab-runner"

echo "GitLab Runner setup complete!"
echo "ArgoCD will now manage the deployment of GitLab Runner and its resources."