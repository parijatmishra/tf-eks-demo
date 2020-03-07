/*
 * Tags to apply to all resources created by this module
 */
variable "default_tags" {
  type = map(string)
}

/* Name of the cluster on which to operate.
 */
variable "cluster_name" {
  type = string
}
