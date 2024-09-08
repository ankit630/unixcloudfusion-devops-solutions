terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "cluster" {
 name = var.cluster_name
}

data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
}

module "efs" {
  source       = "git::https://github.com/ankit630/unixcloudfusion-devops-solutions.git//terraform-modules/efs?ref=efs-v1.0.9"
  vpc_id       = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  subnet_ids   = data.aws_subnets.private.ids
  efs_name     = var.efs_name
  tags       = {
    Environment = "dev"
    Project     = "gitlab-runner"
  }
}
