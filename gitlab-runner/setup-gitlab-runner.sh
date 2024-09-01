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

# Function to create or update IAM Role CloudFormation stack
create_or_update_iam_role_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters=$3

    if aws cloudformation describe-stacks --stack-name "$stack_name" >/dev/null 2>&1; then
        echo "Updating IAM Role stack $stack_name..."
        if ! aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters $parameters; then
            echo "No updates are to be performed on IAM Role stack $stack_name."
            return 0
        fi

        echo "Waiting for IAM Role stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name "$stack_name"
    else
        echo "Creating IAM Role stack $stack_name..."
        if ! aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters $parameters; then
            echo "Failed to create IAM Role stack $stack_name. Check the CloudFormation template for errors."
            return 1
        fi

        echo "Waiting for IAM Role stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name "$stack_name"
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
            --role-arn="$role_arn" \
            --override-existing-serviceaccounts \
            --approve
    else
        echo "Creating ServiceAccount $sa_name..."
        eksctl create iamserviceaccount \
            --cluster="$cluster_name" \
            --namespace="$namespace" \
            --name="$sa_name" \
            --role-arn="$role_arn" \
            --approve
    fi
}

# Prompt user for GitLab Runner token
read -sp "Enter your GitLab Runner token: " RUNNER_TOKEN
echo

# Handle secret in AWS Secrets Manager
echo "Handling secret in AWS Secrets Manager..."
handle_secret

# Create or update IAM Role CloudFormation stack
echo "Creating or updating IAM Role CloudFormation stack..."
if ! create_or_update_iam_role_stack \
    "gitlab-runner-role" \
    "../aws/cloudformation/gitlab-runner/gitlab-runner-role.yaml" \
    "ParameterKey=EksClusterName,ParameterValue=$EKS_CLUSTER_NAME"; then
    echo "Failed to create or update IAM Role stack. Exiting."
    exit 1
fi

# Wait for CloudFormation stacks to complete
echo "Waiting for CloudFormation stacks to complete..."
aws cloudformation wait stack-create-complete --stack-name gitlab-runner-role

# Get the IAM Role ARN
ROLE_ARN=$(aws cloudformation describe-stacks --stack-name gitlab-runner-role --query "Stacks[0].Outputs[?OutputKey=='RoleArn'].OutputValue" --output text)

# Create or update ServiceAccount using eksctl
echo "Creating or updating ServiceAccount using eksctl..."
create_or_update_service_account "$EKS_CLUSTER_NAME" "gitlab-runner" "gitlab-runner-sa" "$ROLE_ARN"

# Apply ArgoCD application
echo "Applying ArgoCD application for GitLab Runner..."
kubectl apply -f ../argocd-apps/gitlab-runner-app.yaml

echo "GitLab Runner setup complete!"
echo "ArgoCD will now manage the deployment of GitLab Runner and its resources."