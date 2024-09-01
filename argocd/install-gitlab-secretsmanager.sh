#!/bin/bash

set -euo pipefail

# Function to check if a command is available
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get EKS cluster names
get_eks_clusters() {
    aws eks list-clusters --query 'clusters[]' --output text
}

# Function to update kubeconfig
update_kubeconfig() {
    local cluster_name=$1
    aws eks update-kubeconfig --name "$cluster_name"
}

# Check for required tools
for cmd in kubectl aws helm sed; do
    if ! command_exists $cmd; then
        echo "$cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Use SELECTED_CLUSTER_NAME if set, otherwise prompt for selection
if [ -z "${SELECTED_CLUSTER_NAME:-}" ]; then
    echo "SELECTED_CLUSTER_NAME is not set. Listing available EKS clusters..."
    clusters=($(get_eks_clusters))

    if [ ${#clusters[@]} -eq 0 ]; then
        echo "No EKS clusters found. Please create an EKS cluster first."
        exit 1
    fi

    if [ ${#clusters[@]} -eq 1 ]; then
        SELECTED_CLUSTER_NAME=${clusters[0]}
        echo "Using the only available cluster: $SELECTED_CLUSTER_NAME"
    else
        echo "Multiple EKS clusters found. Please select one:"
        select cluster in "${clusters[@]}"; do
            if [ -n "$cluster" ]; then
                SELECTED_CLUSTER_NAME=$cluster
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    fi
fi

echo "Using EKS cluster: $SELECTED_CLUSTER_NAME"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Get OIDC Provider URL
OIDC_PROVIDER=$(aws eks describe-cluster --name $SELECTED_CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
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

replace_placeholders "../gitlab-runner/values.yaml"
replace_placeholders "../aws/cloudformation/todoapp/iam-role.yaml"

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