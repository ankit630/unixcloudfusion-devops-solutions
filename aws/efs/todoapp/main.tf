provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "dev_cluster" {
  name = "dev-cluster"
}

data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.dev_cluster.vpc_config[0].vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }

  tags = {
    Type = "private"
  }
}

module "efs" {
  source = "git::https://github.com/ankit630/unixcloudfusion-devops-solutions.git//terraform-modules/efs?ref=efs-v1.0.5"

  subnet_ids         = data.aws_subnets.private.ids
  vpc_id             = data.aws_vpc.eks.id
  efs_name           = "todoapp-efs"
}