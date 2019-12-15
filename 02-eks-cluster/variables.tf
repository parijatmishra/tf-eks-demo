variable "default_tags" {
  type = map(string)
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_private_subnet_ids" {
  type = list(string)
}

data "aws_region" "current" {}
