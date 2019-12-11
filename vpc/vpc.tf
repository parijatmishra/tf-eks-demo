provider "aws" {
  region = "us-east-1"
}

variable "cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "intra_subnets" {
  type = list(string)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "VpcEksTf"

  azs = var.azs

  cidr            = var.cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets   = var.intra_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  # one_nat_gateway_per_az = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Application = "EksClusterTf"
    Environment = "dev"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "vpc_public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "vpc_private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "vpc_intra_subnet_ids" {
  value = module.vpc.intra_subnets
}


output "vpc_nat_public_ips" {
  value = module.vpc.nat_public_ips
}
