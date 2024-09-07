provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "eks" {
  filter {
    name   = "tag:Name"
    values = ["eksctl-dev-cluster-cluster/VPC"]
  }
}

data "aws_subnets" "eks" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks.id]
  }
}

resource "aws_security_group" "efs" {
  name        = "efs-security-group"
  description = "Security group for EFS"
  vpc_id      = data.aws_vpc.eks.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.eks.cidr_block]
  }
}

module "efs" {
  source = "git::https://github.com/ankit630/unixcloudfusion-devops-solutions.git//terraform-modules/efs?ref=efs-v1.0.1"

  creation_token     = var.efs_name
  encrypted          = var.efs_encrypted
  transition_to_ia   = var.efs_transition_to_ia
  tags               = var.efs_tags
  subnet_ids         = data.aws_subnets.eks.ids
  security_group_ids = [aws_security_group.efs.id]
  vpc_id             = data.aws_vpc.eks.id
}