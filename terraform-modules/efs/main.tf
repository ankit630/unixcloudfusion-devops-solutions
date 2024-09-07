resource "aws_efs_file_system" "this" {
  creation_token = var.creation_token
  encrypted      = var.encrypted

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  tags = merge(var.tags, {
    Name = var.creation_token
  })
}

resource "aws_efs_mount_target" "this" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids
}

resource "aws_security_group_rule" "efs_inbound" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
  security_group_id = var.security_group_ids[0]
}

data "aws_vpc" "this" {
  id = var.vpc_id
}