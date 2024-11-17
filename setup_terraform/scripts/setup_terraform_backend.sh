#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

apt install jq -y

# Check for required commands
for cmd in aws jq; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Set up variables
BUCKET_NAME="terraform-state-$ACCOUNT_ID"
DYNAMODB_TABLE_NAME="terraform-locks"
REGION=$(aws configure get region)

# Create S3 bucket if it doesn't exist
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Creating S3 bucket: $BUCKET_NAME"
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration \
        '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
else
    echo "S3 bucket already exists: $BUCKET_NAME"
fi

# Create DynamoDB table if it doesn't exist
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE_NAME" >/dev/null 2>&1; then
    echo "Creating DynamoDB table: $DYNAMODB_TABLE_NAME"
    aws dynamodb create-table --table-name "$DYNAMODB_TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION"
else
    echo "DynamoDB table already exists: $DYNAMODB_TABLE_NAME"
fi

echo "Terraform backend setup complete."
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo "Region: $REGION"

# Create backend configuration file
cat > ../backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$DYNAMODB_TABLE_NAME"
    encrypt        = true
  }
}
EOF

echo "Backend configuration file created: ../backend.tf"
