#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Ansible if not already installed
if ! command_exists ansible; then
    echo "Installing Ansible..."
    sudo apt update
    sudo apt install -y ansible
else
    echo "Ansible is already installed."
fi

# Verify Ansible installation
ansible --version

# Ensure we're in the correct directory
cd ~/magento-setup/infra-automation

# Create a simple inventory file for localhost if it doesn't exist
if [ ! -f "inventory" ]; then
    echo "localhost ansible_connection=local" > inventory
    echo "Created inventory file for localhost."
fi

# Check if environment variables are set
if [ -z "$MAGENTO_PUBLIC_KEY" ] || [ -z "$MAGENTO_PRIVATE_KEY" ]; then
  echo "Error: MAGENTO_PUBLIC_KEY and MAGENTO_PRIVATE_KEY must be set in the environment."
  exit 1
fi

# Run the Ansible playbook
echo "Running Magento setup playbook..."
ansible-playbook -i inventory magento-setup.yaml

echo "Magento setup process completed."
