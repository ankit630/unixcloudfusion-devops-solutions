resource "aws_efs_file_system" "this" {
  creation_token = var.creation_token
  encrypted      = var.encrypted

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  tags = var.tags
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "efs-security-group-${var.creation_token}"
  description = "Security group for EFS ${var.creation_token}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

data "aws_vpc" "this" {
  id = var.vpc_id
}