#!/bin/bash
set -e

# Default values
DEFAULT_COMPONENT="infra-automation"
DEFAULT_REGION=$(aws configure get region || echo "us-east-1")

# Function to setup backend configuration for a component
setup_backend() {
    # Use default value if no argument is provided
    local component="${1:-$DEFAULT_COMPONENT}"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region="${AWS_REGION:-$DEFAULT_REGION}"
    local bucket_name="terraform-state-${account_id}"
    local dynamodb_table="terraform-locks-${component}"

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
            --tags Key=Environment,Value=Production \
                  Key=Project,Value="$component"
        
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
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --region "$region" \
                --tags "Key=Environment,Value=Production" "Key=Project,Value=$component"
        else
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --create-bucket-configuration LocationConstraint="$region" \
                --region "$region" \
                --tags "Key=Environment,Value=Production" "Key=Project,Value=$component"
        fi
        
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
    key            = "terraform-${component}.tfstate"
    region         = "$region"
    dynamodb_table = "$dynamodb_table"
    encrypt        = true
  }
}
EOF

    echo "Backend configuration created for $component"
    echo "State file will be stored at: s3://$bucket_name/terraform-${component}.tfstate"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [component-name]"
    echo "If no component name is provided, default value '$DEFAULT_COMPONENT' will be used"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION: AWS region (default: $DEFAULT_REGION)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 efs"
    echo "  AWS_REGION=us-west-2 $0 ecr"
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Call setup_backend with provided argument or it will use default value
setup_backend "$1"