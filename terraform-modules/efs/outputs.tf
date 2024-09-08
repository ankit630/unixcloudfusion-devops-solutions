output "efs_id" {
  description = "ID of the created EFS file system"
  value       = aws_efs_file_system.efs.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.efs.dns_name
}

output "efs_mount_targets" {
  description = "Mount target IDs and their attributes"
  value       = aws_efs_mount_target.mount_target[*]
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}