#!/bin/bash

# Script to Launch EKS Cluster on Demand in AWS From Scratch

# Step 1: Open CloudShell in your AWS Dashboard

# Step 2: Check if kubectl is installed, if not, download and install it
if ! command -v kubectl &> /dev/null; then
  echo "kubectl not found, installing..."
  curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/darwin/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl is already installed."
fi

# Step 3: Check if eksctl is installed, if not, download and install it
if ! command -v eksctl &> /dev/null; then
  echo "eksctl not found, installing..."
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
  sudo mv /tmp/eksctl /usr/local/bin/
else
  echo "eksctl is already installed."
fi

# Step 4: Create the Kubernetes cluster using eksctl
CLUSTER_NAME="dev-cluster"
REGION="us-east-1"
eksctl create cluster --name $CLUSTER_NAME --version 1.30 --region $REGION --nodegroup-name standard-workers --node-type t3.large --nodes 4 --nodes-min 1 --nodes-max 6 --managed --with-oidc

# After creating the cluster
echo "Installing/Updating VPC CNI addon..."
eksctl create addon --name vpc-cni --version latest --cluster $CLUSTER_NAME --force

# Step 5: Update kubeconfig to connect to the new EKS cluster
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Step 6: Verify kubectl configuration
kubectl get ns
