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

output "private_subnet_ids" {
  value = data.aws_subnets.private.ids
}

output "vpc_id" {
  value = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
}

output "subnet_details" {
  value = [for s in data.aws_subnets.private.ids : {
    id   = s
    tags = data.aws_subnet.details[s].tags
  }]
}

output "all_subnet_ids" {
  value = data.aws_subnets.private.ids
}