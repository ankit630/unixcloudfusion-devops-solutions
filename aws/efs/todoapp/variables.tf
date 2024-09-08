variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "dev-cluster"
}

variable "efs_name" {
  description = "Name of the EFS file system"
  type        = string
  default     = "gitlab-runner-efs"
}

output "subnet_details" {
  value = [for s in data.aws_subnets.private.ids : {
    id   = s
    tags = data.aws_subnet.details[s].tags
  }]
}