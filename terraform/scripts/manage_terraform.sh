#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate component path
validate_path() {
    local path=$1
    if [[ ! "$path" =~ ^terraform/components/.+ ]]; then
        echo "Error: Component path must start with 'terraform/components/'"
        echo "Example: terraform/components/todoapp/ecr"
        exit 1
    fi
}

# Function to manage a Terraform component
manage_component() {
    local component_path=$1
    local action=$2
    shift 2  # Remove first two arguments
    local extra_args="$@"  # Capture remaining arguments

    validate_path "$component_path"

    # Extract component name and project
    local full_component_name=${component_path#terraform/components/}
    local project_name=$(echo "$full_component_name" | cut -d'/' -f1)
    local component_name=$(echo "$full_component_name" | cut -d'/' -f2)
    local state_key="$project_name/$component_name"

    if [ ! -d "$component_path" ]; then
        echo "Error: Component directory $component_path does not exist"
        exit 1
    fi

    echo "Managing component: $component_name"
    echo "Project: $project_name"
    echo "State key: $state_key"

    # Navigate to component directory
    cd "$component_path"

    # Setup backend for this component
    echo "Setting up backend configuration..."
    ../../../scripts/setup_terraform_backend.sh "$state_key"

    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init

    case "$action" in
        apply)
            echo "Applying Terraform configuration..."
            terraform apply $extra_args
            ;;
        destroy)
            echo "Destroying Terraform resources..."
            terraform destroy $extra_args
            ;;
        plan)
            echo "Planning Terraform changes..."
            terraform plan $extra_args
            ;;
        output)
            echo "Showing Terraform outputs..."
            terraform output $extra_args
            ;;
        import)
            if [ -z "$extra_args" ]; then
                echo "Error: Import requires resource address and ID"
                echo "Usage: $0 <component-path> import <resource_address> <resource_id>"
                exit 1
            fi
            echo "Importing resource..."
            terraform import $extra_args
            ;;
        *)
            echo "Invalid action. Use: apply, destroy, plan, output, or import"
            exit 1
            ;;
    esac

    cd - > /dev/null
}

# Main script execution
if [ $# -lt 2 ]; then
    echo "Usage: $0 <component-path> <action> [additional terraform arguments]"
    echo "Component path must start with 'terraform/components/'"
    echo "Example paths:"
    echo "  terraform/components/todoapp/ecr"
    echo "  terraform/components/todoapp/efs"
    echo "Actions: apply, destroy, plan, output, import"
    echo ""
    echo "Examples:"
    echo "  $0 terraform/components/todoapp/ecr plan"
    echo "  $0 terraform/components/todoapp/efs apply -auto-approve"
    echo "  $0 terraform/components/todoapp/ecr import aws_ecr_repository.repo repository_name"
    exit 1
fi

component_path=$1
action=$2
shift 2  # Remove first two arguments
extra_args="$@"  # Capture remaining arguments

manage_component "$component_path" "$action" "$extra_args"