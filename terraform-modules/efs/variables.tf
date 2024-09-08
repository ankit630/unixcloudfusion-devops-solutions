variable "vpc_id" {
  description = "VPC ID where EFS will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for mount targets"
  type        = list(string)
}

variable "efs_name" {
  description = "Name of the EFS file system"
  type        = string
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}