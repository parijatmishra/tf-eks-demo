output "vpc_id" {
  value = module.vpc.vpc_id
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
