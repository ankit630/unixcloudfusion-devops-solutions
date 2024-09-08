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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}