set -e

# Navigate to the EFS directory
cd "$(dirname "$0")/aws/efs"

# Initialize Terraform
terraform init

# Plan Terraform changes
terraform plan -out=tfplan

# Apply Terraform changes
terraform apply tfplan