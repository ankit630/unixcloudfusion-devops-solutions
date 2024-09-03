provider "aws" {
  region = var.aws_region
}

module "ecr" {
  source = "https://github.com/ankit630/unixcloudfusion-devops-solutions.git//ecr?ref=v1.0.0"
  
  repository_name = var.repository_name
}

output "repository_url" {
  value = module.ecr.repository_url
}