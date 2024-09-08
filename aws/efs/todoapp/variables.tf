variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "efs_name" {
  description = "Name of the EFS file system"
  type        = string
  default     = "gitlab-runner-efs"
}