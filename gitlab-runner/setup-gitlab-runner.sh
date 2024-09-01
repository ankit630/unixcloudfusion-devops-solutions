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

# Prompt user for GitLab Runner token
read -sp "Enter your GitLab Runner token: " RUNNER_TOKEN
echo

# Function to handle AWS Secrets Manager secret
handle_secret() {
    local secret_name="gitlab/gitlab-runner-secrets"
    local new_secret_string="{\"runner-token\":\"$RUNNER_TOKEN\",\"runner-registration-token\":\"\"}"

    # Check if the secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" >/dev/null 2>&1; then
        echo "Secret already exists. Checking if update is needed..."
        
        # Get the current secret value
        local current_secret_string=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --query SecretString --output text)
        
        # Compare current and new secret strings
        if [ "$current_secret_string" = "$new_secret_string" ]; then
            echo "Secret is up to date. No changes needed."
        else
            echo "Secret content has changed. Updating..."
            aws secretsmanager update-secret \
                --secret-id "$secret_name" \
                --secret-string "$new_secret_string"
        fi
    else
        echo "Secret does not exist. Creating new secret..."
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "GitLab Runner secrets" \
            --secret-string "$new_secret_string"
    fi
}

# [Previous variable definitions and user prompts remain unchanged]

# Prompt user for GitLab Runner token
read -sp "Enter your GitLab Runner token: " RUNNER_TOKEN
echo

# Handle secret in AWS Secrets Manager
echo "Handling secret in AWS Secrets Manager..."
handle_secret

# Function to create or update CloudFormation stack
create_or_update_cloudformation_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters=$3

    # Check if the stack exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" >/dev/null 2>&1; then
        echo "Stack $stack_name already exists. Updating..."
        if ! aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters $parameters; then
            echo "No updates are to be performed on stack $stack_name."
            return
        fi

        # Wait for stack update to complete
        echo "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name "$stack_name"
    else
        echo "Stack $stack_name does not exist. Creating..."
        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameters $parameters

        # Wait for stack creation to complete
        echo "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name "$stack_name"
    fi
}

# Create or update CloudFormation stacks
echo "Creating or updating ServiceAccount CloudFormation stack..."
create_or_update_cloudformation_stack \
    "gitlab-runner-service-account" \
    "../aws/cloudformation/gitlab-runner/serviceaccount.yaml" \
    "ParameterKey=EksClusterName,ParameterValue=$EKS_CLUSTER_NAME"

echo "Creating or updating IAM Role CloudFormation stack..."
create_or_update_cloudformation_stack \
    "gitlab-runner-role" \
    "../aws/cloudformation/gitlab-runner/gitlab-runner-role.yaml" \
    "ParameterKey=EksClusterName,ParameterValue=$EKS_CLUSTER_NAME"

# Wait for CloudFormation stacks to complete
echo "Waiting for CloudFormation stacks to complete..."
aws cloudformation wait stack-create-complete --stack-name gitlab-runner-service-account
aws cloudformation wait stack-create-complete --stack-name gitlab-runner-role

# Apply ArgoCD application
echo "Applying ArgoCD application for GitLab Runner..."
kubectl apply -f ../argocd-apps/gitlab-runner-app.yaml

echo "GitLab Runner setup complete!"
echo "ArgoCD will now manage the deployment of GitLab Runner and its resources."