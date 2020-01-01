module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = var.vpc_name # tag Name=...

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

  tags = var.default_tags

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_default_route_table" "r" {
  default_route_table_id = module.vpc.default_route_table_id

  tags = merge({ "Name" = "${var.vpc_name}-default" }, var.default_tags)
}

resource "aws_default_security_group" "s" {
  vpc_id = module.vpc.vpc_id

  tags = merge({ "Name" = "${var.vpc_name}-default" }, var.default_tags)
}
