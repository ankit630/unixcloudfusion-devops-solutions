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

# Set paths for templates
IAM_ROLE_TEMPLATE="../aws/cloudformation/todoapp/iam-role.yaml"
GITLAB_RUNNER_VALUES="../gitlab-runner/values.yaml"

echo "IAM_ROLE_TEMPLATE is set to: $IAM_ROLE_TEMPLATE"
echo "GITLAB_RUNNER_VALUES is set to: $GITLAB_RUNNER_VALUES"

# Function to replace placeholders in yaml files
replace_placeholders() {
    local file=$1
    sed -i.bak \
        -e "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" \
        -e "s|OIDC_PROVIDER|$OIDC_PROVIDER|g" \
        "$file"
    rm "${file}.bak"
}

# Function to read ArgoCD password from file
read_argocd_password() {
    local password_file="argocd-admin-password.txt"
    if [[ -f "$password_file" ]]; then
        ARGOCD_PASSWORD=$(cat "$password_file")
        if [[ -z "$ARGOCD_PASSWORD" ]]; then
            echo "Error: ArgoCD password file is empty."
            exit 1
        fi
    else
        echo "Error: ArgoCD password file not found at $password_file"
        exit 1
    fi
}

# Replace placeholders in yaml files
replace_placeholders "$IAM_ROLE_TEMPLATE"
replace_placeholders "$GITLAB_RUNNER_VALUES"

# Deploy CloudFormation stack for IAM roles
aws cloudformation deploy \
    --template-file "$IAM_ROLE_TEMPLATE" \
    --stack-name eks-service-account-roles \
    --capabilities CAPABILITY_NAMED_IAM

# Install ArgoCD CLI
if ! command_exists argocd; then
    echo "Installing ArgoCD CLI..."
    # Add installation command for your OS here
fi

# Function to install ArgoCD CLI
install_argocd_cli() {
    echo "Installing ArgoCD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    echo "ArgoCD CLI installed successfully."
}

# Function to check and install ArgoCD CLI if needed
check_argocd_cli() {
    if ! command -v argocd &> /dev/null; then
        echo "ArgoCD CLI is not installed. Installing now..."
        install_argocd_cli
    else
        echo "ArgoCD CLI is already installed."
    fi
}

# Check and install ArgoCD CLI if needed
check_argocd_cli

# Read ArgoCD password from file
read_argocd_password
echo "ArgoCD password read from file."

# Get ArgoCD server URL
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [[ -z "$ARGOCD_SERVER" ]]; then
    echo "Error: Unable to get ArgoCD server URL. Please make sure ArgoCD is properly installed and the service is exposed."
    exit 1
fi

# Login to ArgoCD
argocd login "$ARGOCD_SERVER" --insecure --username admin --password $ARGOCD_PASSWORD

GITOPS_REPO_URL="https://github.com/ankit630/unixcloudfusion-devops-solutions"

# Create ArgoCD applications

argocd app create external-secrets-operator \
    --repo $GITOPS_REPO_URL \
    --path external-secrets-operator \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace kube-system \
    --sync-policy automated

echo "Setup complete! ArgoCD is now managing Secret Manager installations."