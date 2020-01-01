/* The name of the VPC where this bastion node lives. Used to generate a
 * name for the bastion node.
 *
 * E.g. "ProductXVPC"
 */
variable "vpc_name" {
  type = string
}

/* Additional tags to apply to all resources created by this module.
 */
variable "default_tags" {
  type = map
}

/* ID of the VPC where the bastion is to be launched. We cannot derive it
 * from the name
 */
variable "vpc_id" {
  type = string
}

/* CIDR blocks from where incoming SSH access should be allowed. A list
 * of strings, each containing a CIDR block (a.b.c.d/x). Can be empty
 * (if you exclusively use SSM to access it, for e.g.).
 */
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = []
}

/* EC2 AMI ID to use for launching the bastion EC2 instance.
 * Note: our user_data.sh assumes we are using Amazon Linux 2.
 */
variable "ami" {
  type = string
}

/* EC2 instance type to use for the bastion instance. */
variable "instance_type" {
  type    = string
  default = "t3a.small"
}

/* ID of a public subnet in which to launch the instance. */
variable "subnet_id" {
  type = string
}

/* Name of the EC2 SSH Keypair to use */
variable "key_name" {
  type = string
}
