#!/bin/bash

set -euo pipefail

# Function to check if a command is available
command_exists() {
    command -v "$1" &> /dev/null
}

# Check for required tools
for cmd in kubectl aws helm sed; do
    if ! command_exists $cmd; then
        echo "$cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Get OIDC Provider URL
OIDC_PROVIDER=$(aws eks describe-cluster --name your-cluster-name --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
echo "OIDC Provider: $OIDC_PROVIDER"

# Function to replace placeholders in yaml files
replace_placeholders() {
    local file=$1
    sed -i.bak \
        -e "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" \
        -e "s|OIDC_PROVIDER|$OIDC_PROVIDER|g" \
        "$file"
    rm "${file}.bak"
}

# Replace placeholders in yaml files

replace_placeholders "gitlab-runner/values.yaml"
replace_placeholders "aws/cloudformation/todoapp/iam-role.yaml"

# Deploy CloudFormation stack for IAM roles
aws cloudformation deploy \
    --template-file aws/cloudformation/todoapp/iam-role.yaml \
    --stack-name eks-service-account-roles \
    --capabilities CAPABILITY_NAMED_IAM

# Install ArgoCD CLI
if ! command_exists argocd; then
    echo "Installing ArgoCD CLI..."
    # Add installation command for your OS here
fi

# Login to ArgoCD
argocd login --insecure --username admin --password $ARGOCD_PASSWORD

# Create ArgoCD applications
argocd app create gitlab-runner \
    --repo https://github.com/your-repo/gitops-eks-setup.git \
    --path gitlab-runner \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace gitlab-runner \
    --sync-policy automated

argocd app create secret-manager \
    --repo https://github.com/your-repo/gitops-eks-setup.git \
    --path secret-manager \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace kube-system \
    --sync-policy automated

echo "Setup complete! ArgoCD is now managing GitLab Runner and Secret Manager installations."