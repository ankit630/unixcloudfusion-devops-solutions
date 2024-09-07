variable "creation_token" {
  description = "A unique name for the EFS file system"
  type        = string
}

variable "encrypted" {
  description = "Whether to enable encryption for the EFS file system"
  type        = bool
  default     = true
}

variable "transition_to_ia" {
  description = "Lifecycle policy for transition to IA storage class"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "tags" {
  description = "Tags to apply to the EFS file system"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "List of subnet IDs to create mount targets in"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to apply to the mount targets"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC where EFS will be created"
  type        = string
}

variable "create_security_group_rule" {
  description = "Whether to create the security group rule"
  type        = bool
  default     = true
}

