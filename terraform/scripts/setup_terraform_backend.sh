#!/bin/bash
set -e

# Function to sanitize names for DynamoDB
sanitize_name() {
    # Replace '/' with '-' and any other invalid characters
    echo "$1" | tr '/' '-'
}

# Function to setup backend configuration for a component
setup_backend() {
    # Use default value if no argument is provided
    local component="${1:-infra-automation}"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region="${AWS_REGION:-$(aws configure get region)}"
    local bucket_name="terraform-state-${account_id}"
    # Sanitize the component name for DynamoDB table
    local dynamodb_table="terraform-locks-$(sanitize_name $component)"

    echo "Setting up Terraform backend with:"
    echo "Component: $component"
    echo "Region: $region"
    echo "Bucket: $bucket_name"
    echo "DynamoDB Table: $dynamodb_table"

    # Create DynamoDB table if it doesn't exist
    if ! aws dynamodb describe-table --table-name "$dynamodb_table" >/dev/null 2>&1; then
        echo "Creating DynamoDB table: $dynamodb_table"
        aws dynamodb create-table \
            --table-name "$dynamodb_table" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$region" \
            --tags Key=Environment,Value=Production Key=Project,Value="$component"
        
        # Wait for table to be created
        echo "Waiting for DynamoDB table to be ready..."
        aws dynamodb wait table-exists --table-name "$dynamodb_table"
    else
        echo "DynamoDB table $dynamodb_table already exists"
    fi

    # Create S3 bucket if it doesn't exist
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "Creating S3 bucket: $bucket_name"
        if [ "$region" = "us-east-1" ]; then
            # Create bucket
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --region "$region"
        else
            # Create bucket in non-us-east-1 region
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --create-bucket-configuration LocationConstraint="$region" \
                --region "$region"
        fi

        # Add tags to bucket separately
        aws s3api put-bucket-tagging \
            --bucket "$bucket_name" \
            --tagging 'TagSet=[{Key=Environment,Value=Production},{Key=Project,Value=terraform-backend}]'
        
        # Enable versioning
        echo "Enabling versioning on S3 bucket..."
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable encryption
        echo "Enabling encryption on S3 bucket..."
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration \
            '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

        # Enable bucket blocking public access
        echo "Blocking public access on S3 bucket..."
        aws s3api put-public-access-block \
            --bucket "$bucket_name" \
            --public-access-block-configuration \
            'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
    else
        echo "S3 bucket $bucket_name already exists"
    fi

    # Create backend configuration file
    echo "Creating backend configuration file..."
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$bucket_name"
    key            = "terraform-$component.tfstate"
    region         = "$region"
    dynamodb_table = "$dynamodb_table"
    encrypt        = true
  }
}
EOF

    echo "Backend configuration created for $component"
    echo "State file will be stored at: s3://$bucket_name/terraform-$component.tfstate"
}

# Main script execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <component-name>"
    echo "Example: $0 efs"
    exit 1
fi

setup_backend "$1"