# Magento 2 Automated Deployment

This repository contains an automated solution for provisioning an AWS server using Terraform and deploying Magento 2 using Ansible on a Debian-based system.

## Overview

This setup automates the following:

1. AWS EC2 instance provisioning (via Terraform)
2. Magento 2 installation and configuration
3. LEMP stack setup (Linux, Nginx, MariaDB, PHP)
4. Redis installation and configuration
5. Elasticsearch setup
6. Varnish installation and configuration
7. SSL setup with self-signed certificate

## Prerequisites

- AWS account with appropriate permissions
- Git
- Bash shell

## Quick Start

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/your-repo-name.git
   cd your-repo-name
   ```

2. Set up the required environment variables:
   ```
   export MAGENTO_PUBLIC_KEY=your_public_key
   export MAGENTO_PRIVATE_KEY=your_private_key
   export MAGENTO_DB_PASSWORD=your_db_password
   export MAGENTO_ADMIN_PASSWORD=your_admin_password
   ```

3. Run the setup script:
   ```
   bash -x run-magento-setup.sh
   ```

## What the Setup Does

The `run-magento-setup.sh` script automates the following:

1. Installs Ansible if not already present
2. Executes the Ansible playbook to:
   - Install and configure Nginx
   - Install and configure MariaDB (MySQL-compatible)
   - Install PHP 8.1 and necessary extensions
   - Install and configure Redis for caching and sessions
   - Install and configure Elasticsearch
   - Install Magento 2 via Composer
   - Configure Magento 2 with sample data and Elasticsearch
   - Set up Varnish as a caching layer
   - Generate and configure a self-signed SSL certificate
   - Install and configure phpMyAdmin

## Accessing Magento

After the setup is complete:

1. Add an entry to your local `/etc/hosts` file:
   ```
   your_ec2_instance_ip test.mgt.com pma.mgt.com
   ```

2. Access Magento in your browser:
   - Frontend: `https://test.mgt.com`
   - Admin panel: `https://test.mgt.com/admin`
   - phpMyAdmin: `https://pma.mgt.com`

   Note: You'll need to accept the security warning due to the self-signed certificate.

3. Log in to the Magento admin panel using:
   - Username: admin
   - Password: The value you set for MAGENTO_ADMIN_PASSWORD

## Important Notes

- This setup uses a self-signed SSL certificate, which is suitable for development but not for production use.
- The MariaDB root password and other sensitive information are stored in `/root/magento_credentials/` on the server.
- For production use, ensure you properly secure your server and use a valid SSL certificate.

## Customization

- Terraform configurations can be modified in the `ec2/` directory.
- Ansible roles and playbooks are located in the `infra-automation/` directory.

## Troubleshooting

- If you encounter any issues, check the Ansible log output for error messages.
- Ensure all required environment variables are correctly set.
- Verify that your AWS credentials are properly configured if you're having issues with Terraform.

