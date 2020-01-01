/* Name of the VPC. The VPC will be given a tag Name=*this value*. Child
 * resources will be given tags "Name=*this-value*-*something*", where
 * something depends on the kind of resource. Do not include a Name tag
 * in `default_tags` below or it will conflict with this value.
 */
variable "vpc_name" {
  type = string
}

/* Additional tags to apply to all resources created by this module.
 */
variable "default_tags" {
  type = map
}

/* Which AZs to use - must specify exactly three, as a list of strings, each
 * containing an az name.
 *
 * E.g.:
 * azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
 */
variable "azs" {
  type = list(string)
}

/* IP Address Range for the VPC, in the CIDR format: a.b.c.d/x
 * E.g.: cidr            = "10.2.0.0/16"
 */
variable "cidr" {
  type = string
}

/* IP Address Ranges of the public subnets, as a list of exactly 3 strings,
 * each containing a network block in the CIDR format (a.b.c.d/x). The blocks
 * must be subsets of the `cidr` variable and and must not overlap with each
 * other or other `*_subnet` variable values.
 * These subnets have a route to the internet gateway and have public IP address
 * assignment to EC2 instances enables by default. They are used to launch
 * public load balancers, and nat gateways.
 *
 * E.g.:
 * public_subnets  = ["10.2.0.0/20", "10.2.16.0/20", "10.2.32.0/20"]
 */
variable "public_subnets" {
  type = list(string)
}

/* IP Address Ranges of the private subnets, as a list of exactly 3 strings,
 * each containing a network block in the CIDR format (a.b.c.d/x). The blocks
 * must be subsets of the `cidr` variable and and must not overlap with each
 * other or other `*_subnet` variable values.
 * These subnets have a route to the internet via Nat Gateways, and don't have
 * public IP address assignment enabled.
 * These subnets are used to launch the cluster node groups (or worker nodes),
 * the control plane's network interfaces, and internal load balancers.
 * 
 * E.g.:
 * private_subnets = ["10.2.64.0/19", "10.2.96.0/19", "10.2.128.0/19"]
 */
variable "private_subnets" {
  type = list(string)
}

/* IP Address Ranges of the `internal' subnets, as a list of exactly 3 strings,
 * each containing a network block in the CIDR format (a.b.c.d/x). The blocks
 * must be subsets of the `cidr` variable and and must not overlap with each
 * other or other `*_subnet` variable values.
 * These subnets don't have a route to the internet at all, and don't have
 * public IP address assignment enabled.
 * These subnets are not used by our Amazon EKS cluster, but can be used to
 * lanunch services that don't need access to the internet, such as RDS instances,
 * managed Amazon Elastic Search clusters, etc.
 *
 * E.g.:
 * intra_subnets   = ["10.2.192.0/21", "10.2.200.0/21", "10.2.208.0/21"]
 */
variable "intra_subnets" {
  type = list(string)
}
