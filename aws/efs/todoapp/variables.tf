variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "efs_name" {
  description = "Name for the EFS file system"
  type        = string
  default     = "my-efs"
}

variable "efs_encrypted" {
  description = "Whether to enable encryption for the EFS file system"
  type        = bool
  default     = true
}

variable "efs_transition_to_ia" {
  description = "Lifecycle policy for transition to IA storage class"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "efs_tags" {
  description = "Tags to apply to the EFS file system"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "my-project"
  }
}

variable "vpc_id" {
  description = "ID of the VPC where EFS will be created"
  type        = string
}