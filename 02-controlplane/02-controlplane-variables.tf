/* Additional tags to apply to all resources created by this module.
 */
variable "default_tags" {
  type = map
}

/* Name of the EKS cluster. */
variable "cluster_name" {
  type = string
}

/* ID of the VPC where the bastion is to be launched. We cannot derive it
 * from the name
 */
variable "vpc_id" {
  type = string
}

/* IDs of the private subnets where EKS should use */
variable "vpc_private_subnet_ids" {
  type = list(string)
}

/* This module will create a Kubeconfig file. Specify the full path to its location. */
variable "kubeconfig_path" {
  type = string
}

data "aws_region" "current" {}
