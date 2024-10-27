#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Terraform if not already installed
if ! command_exists terraform; then
    echo "Installing Terraform..."
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    sudo yum -y install terraform
else
    echo "Terraform is already installed."
fi

# Verify Terraform installation
terraform version

# Assume we're already in the directory with Terraform files

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create a plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Apply the plan
echo "Applying Terraform plan..."
terraform apply tfplan

# Output the results
echo "EC2 instance has been created. Details:"
terraform output

echo "Terraform execution completed successfully."
