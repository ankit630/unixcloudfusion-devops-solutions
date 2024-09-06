#!/bin/bash

set -e

# Fetch the EFS ID
EFS_ID=$(aws efs describe-file-systems --query "FileSystems[0].FileSystemId" --output text)

if [ -z "$EFS_ID" ]; then
    echo "Error: No EFS file system found."
    exit 1
fi

# Generate the ConfigMap YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: efs-config
  namespace: gitlab-runner
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
data:
  EFS_ID: $EFS_ID
EOF

echo "ConfigMap updated with EFS ID: $EFS_ID"