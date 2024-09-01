#!/bin/bash

set -euo pipefail

# Function to get AWS Account ID
get_aws_account_id() {
    aws sts get-caller-identity --query "Account" --output text
}

# Function to get EKS Cluster Name
get_eks_cluster_name() {
    # This assumes you have only one EKS cluster. If you have multiple, you might need to adjust this.
    aws eks list-clusters --query "clusters[0]" --output text
}

# Function to get AWS Region
get_aws_region() {
    aws configure get region
}

# Function to get GitLab URL
get_gitlab_url() {
    # This is a placeholder. You might want to store this in a config file or environment variable.
    echo "https://gitlab.your-domain.com"
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
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${EKS_CLUSTER_NAME}.oidc.eks.${AWS_REGION}.amazonaws.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${EKS_CLUSTER_NAME}.oidc.eks.${AWS_REGION}.amazonaws.com:sub": "system:serviceaccount:gitlab-runner:gitlab-runner-sa"
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
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)

    # Get the role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text)
    echo "Role ARN: $ROLE_ARN"
}

# Function to check and create IAM OIDC provider
ensure_iam_oidc_provider() {
    local cluster_name=$1
    local region=$2

    echo "Checking for IAM OIDC provider..."
    if ! eksctl utils associate-iam-oidc-provider --cluster="$cluster_name" --region="$region" --approve --status; then
        echo "IAM OIDC provider not found. Creating..."
        eksctl utils associate-iam-oidc-provider --cluster="$cluster_name" --region="$region" --approve
    else
        echo "IAM OIDC provider already exists."
    fi
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

# Prompt user for GitLab Runner token
read -sp "Enter your GitLab Runner token: " RUNNER_TOKEN
echo

# Handle secret in AWS Secrets Manager
echo "Handling secret in AWS Secrets Manager..."
handle_secret

# Ensure IAM OIDC provider exists
echo "Ensuring IAM OIDC provider exists..."
ensure_iam_oidc_provider "$EKS_CLUSTER_NAME" "$AWS_REGION"

# Create or update IAM Role using AWS CLI
echo "Creating or updating IAM Role..."
create_or_update_iam_role

# Create or update ServiceAccount using eksctl
echo "Creating or updating ServiceAccount using eksctl..."
create_or_update_service_account "$EKS_CLUSTER_NAME" "gitlab-runner" "gitlab-runner-sa" "$ROLE_ARN"

# Apply ArgoCD application
echo "Applying ArgoCD application for GitLab Runner..."
kubectl apply -f ../argocd-apps/gitlab-runner-app.yaml

echo "GitLab Runner setup complete!"
echo "ArgoCD will now manage the deployment of GitLab Runner and its resources."