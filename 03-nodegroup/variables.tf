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

variable "ssh_keypair_name" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}
