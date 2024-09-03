#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get the latest Terraform version
get_latest_terraform_version() {
    curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version
}

# Function to install Terraform
install_terraform() {
    local version=$1
    echo "Installing Terraform version $version..."
    
    # Determine OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi

    # Download and install Terraform
    TF_URL="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${OS}_${ARCH}.zip"
    curl -LO $TF_URL
    unzip terraform_${version}_${OS}_${ARCH}.zip
    mkdir -p $HOME/bin
    mv terraform $HOME/bin/
    export PATH=$PATH:$HOME/bin
    rm terraform_${version}_${OS}_${ARCH}.zip

    echo "Terraform installed successfully."
}

# Check for required commands
for cmd in curl jq unzip aws; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Get the latest Terraform version
LATEST_TF_VERSION=$(get_latest_terraform_version)

# Check if Terraform is installed, install if not
if ! command_exists terraform; then
    install_terraform $LATEST_TF_VERSION
else
    INSTALLED_VERSION=$(terraform version -json | jq -r '.terraform_version')
    if [ "$INSTALLED_VERSION" != "$LATEST_TF_VERSION" ]; then
        echo "Installed Terraform version ($INSTALLED_VERSION) differs from the latest version ($LATEST_TF_VERSION)."
        read -p "Do you want to install Terraform $LATEST_TF_VERSION? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_terraform $LATEST_TF_VERSION
        else
            echo "Proceeding with installed Terraform version $INSTALLED_VERSION"
        fi
    fi
fi

# Change to the directory containing this script
cd "$(dirname "$0")"

# Run the Terraform backend setup script
../../../setup_terraform/scripts/setup_terraform_backend.sh

# Copy the backend configuration
cp ../../../setup_terraform/backend.tf .

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create a Terraform plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Apply the Terraform plan
echo "Applying Terraform plan..."
terraform apply tfplan

# Output the repository URL
echo "ECR Repository created successfully!"
echo "Repository URL: $(terraform output -raw repository_url)"