output "efs_id" {
  value = module.efs.efs_id
}

output "efs_dns_name" {
  value = module.efs.efs_dns_name
}

output "efs_security_group_id" {
  value = module.efs.efs_security_group_id
}

output "efs_mount_targets" {
  value = module.efs.efs_mount_targets
}

output "vpc_id" {
  value = data.aws_vpc.eks_vpc.id
}

output "subnet_ids" {
  value = data.aws_subnets.all.ids
}