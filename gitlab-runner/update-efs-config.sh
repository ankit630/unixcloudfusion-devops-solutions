#!/bin/bash

# Get the EFS ID
EFS_ID=$(aws efs describe-file-systems --query "FileSystems[0].FileSystemId" --output text)

# Replace the placeholder in the efs-provisioner.yaml file
sed -i "s/\${EFS_ID}/$EFS_ID/" efs-provisioner.yaml

# Apply the changes using kubectl
kubectl apply -f efs-provisioner.yaml

# Trigger ArgoCD to sync the changes
argocd app sync gitlab-runner