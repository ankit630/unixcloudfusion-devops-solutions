#!/bin/bash

set -e

# Function to setup backend configuration for a component
setup_backend() {
    local component=$1
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region=$(aws configure get region)
    local bucket_name="terraform-state-${account_id}"
    local dynamodb_table="terraform-locks-${component}"

    # Create DynamoDB table if it doesn't exist
    if ! aws dynamodb describe-table --table-name "$dynamodb_table" >/dev/null 2>&1; then
        echo "Creating DynamoDB table: $dynamodb_table"
        aws dynamodb create-table \
            --table-name "$dynamodb_table" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$region"
    fi

    # Create S3 bucket if it doesn't exist
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "Creating S3 bucket: $bucket_name"
        if [ "$region" = "us-east-1" ]; then
            aws s3api create-bucket --bucket "$bucket_name"
        else
            aws s3api create-bucket --bucket "$bucket_name" \
                --create-bucket-configuration LocationConstraint="$region"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration \
            '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
    fi

    # Create backend configuration file
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$bucket_name"
    key            = "terraform-${component}.tfstate"
    region         = "$region"
    dynamodb_table = "$dynamodb_table"
    encrypt        = true
  }
}
EOF

    echo "Backend configuration created for $component"
}

# Main script execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <component-name>"
    echo "Example: $0 efs"
    exit 1
fi

setup_backend "$1"