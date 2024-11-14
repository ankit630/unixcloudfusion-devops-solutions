variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  default     = "magento2-terraform-state"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  default     = "magento2-terraform-locks"
}

variable "debian_11_ami" {
  description = "AMI ID for Debian 11"
  default     = "ami-064519b8c76274859"  # This is an AMI ID from us-east-1 , please replace with the correct one for your region
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  default     = "magento2"
}
