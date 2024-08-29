#!/bin/bash

set -euo pipefail

# Function to get EKS cluster names
get_eks_clusters() {
    aws eks list-clusters --query 'clusters[]' --output text
}

# Function to update kubeconfig
update_kubeconfig() {
    local cluster_name=$1
    aws eks update-kubeconfig --name "$cluster_name"
}

# Function to test kubectl connection
test_kubectl_connection() {
    if kubectl get nodes &>/dev/null; then
        echo "Successfully connected to the Kubernetes cluster."
    else
        echo "Failed to connect to the Kubernetes cluster. Please check your configuration."
        exit 1
    fi
}

# Main execution starts here

# Get EKS cluster names
clusters=($(get_eks_clusters))

# Check if there are any clusters
if [ ${#clusters[@]} -eq 0 ]; then
    echo "No EKS clusters found. Please create an EKS cluster first."
    exit 1
fi

# If there's only one cluster, use it. Otherwise, prompt for selection.
if [ ${#clusters[@]} -eq 1 ]; then
    selected_cluster=${clusters[0]}
    echo "Using the only available cluster: $selected_cluster"
else
    echo "Multiple EKS clusters found. Please select one:"
    select cluster in "${clusters[@]}"; do
        if [ -n "$cluster" ]; then
            selected_cluster=$cluster
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

# Update kubeconfig for the selected cluster
echo "Updating kubeconfig for cluster: $selected_cluster"
update_kubeconfig "$selected_cluster"

# Test kubectl connection
echo "Testing connection to the Kubernetes cluster..."
test_kubectl_connection

# Create ArgoCD namespace
echo "Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Apply ArgoCD Kustomization
echo "Applying ArgoCD Kustomization..."
kubectl kustomize --enable-helm | kubectl apply -f -

echo "ArgoCD installation complete!"

# Patch ArgoCD server to use LoadBalancer type (for easy access)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Generate a random password
ARGOCD_PASSWORD=$(openssl rand -base64 32)

# Generate a random session key
ARGOCD_SESSION_KEY=$(openssl rand -base64 32)

# Create the secret
kubectl -n argocd create secret generic argocd-secret \
  --from-literal=admin.password=$(htpasswd -bnBC 10 "" $ARGOCD_PASSWORD | tr -d ':\n') \
  --from-literal=admin.passwordMtime=$(date +%FT%T%Z) \
  --from-literal=server.secretkey=$ARGOCD_SESSION_KEY

# Save the admin password somewhere secure
echo $ARGOCD_PASSWORD > argocd-admin-password.txt