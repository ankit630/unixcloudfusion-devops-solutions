#!/bin/bash

set -e

# Fetch the EFS ID
EFS_ID=$(aws efs describe-file-systems --query "FileSystems[?Name=='my-gitlab-runner-efs'].FileSystemId" --output text)

if [ -z "$EFS_ID" ]; then
    echo "Error: No EFS file system found."
    exit 1
fi

# Update the ConfigMap with the EFS ID
kubectl create configmap efs-config \
    --from-literal=EFS_ID=$EFS_ID \
    -n gitlab-runner \
    --dry-run=client -o yaml | kubectl apply -f -

# After creating or updating the ConfigMap
echo "ConfigMap updated with EFS ID: $EFS_ID"