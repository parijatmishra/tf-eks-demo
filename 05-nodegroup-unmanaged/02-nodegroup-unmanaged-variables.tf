/*
 * Tags to apply to all resources created by this module
 */
variable "default_tags" {
  type = map(string)
}

/* Name of the cluster to attach node groups to.
 */
variable "cluster_name" {
  type = string
}

/*
 * The VPC in which to create the Node Groups
 */
variable "vpc_id" {
  type = string
}

/* IDs of the (private) subnets in which to launch the Auto-Scaling Groups
 * forming our node groups. There must be exactly 3 subnets and they
 * must belong to the VPC above.
 */
variable "vpc_private_subnet_ids" {
  type = list(string)
}

/* Name of an EC2 SSH keypair so we can SSH into the EC2 instances
 * serving as our nodes.
 */
variable "ssh_keypair_name" {
  type = string
}

/* EC2 Security Group ID of the cluster's control plane security group.
 * Node Group security group will allow all communication between this and
 * itself
 */
variable "cluster_security_group_id" {
  type = string
}

/* EC2 Security Group IDs from which to allow SSH into Node Groups. List of
 * string, each being a security group ID. List can be empty.
 */
variable "allow_ssh_security_group_ids" {
  type = list(string)
}

/* The ARN of the EC2 Instance Profile to use for the Node Group EC2 Instances.
 * This was created earlier in another module.
 */
variable "nodegroup_iam_instance_profile_arn" {
  type = string
}

/* EC2 Instance Type for the Node Group instances. */
variable "instance_type" {
  type = string
}
