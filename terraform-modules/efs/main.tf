resource "aws_efs_file_system" "efs" {
  creation_token = var.efs_name
  encrypted      = true

  tags = merge(
    {
      Name = var.efs_name
    },
    var.tags
  )
}

resource "aws_security_group" "efs" {
  name        = "${var.efs_name}-efs-sg"
  description = "Allow NFS traffic for EFS"
  vpc_id      = var.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.efs_name}-efs-sg"
    },
    var.tags
  )
}

resource "aws_efs_mount_target" "mount_target" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}