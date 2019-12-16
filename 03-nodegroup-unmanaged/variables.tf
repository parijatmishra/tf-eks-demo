variable "default_tags" {
  type = map(string)
}

variable "default_tags_asg" {
  type = list(object({ key = string, value = string, propagate_at_launch = bool }))
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
