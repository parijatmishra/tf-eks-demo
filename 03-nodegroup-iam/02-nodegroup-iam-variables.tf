/* Additional tags to apply to all resources created by this module.
 */
variable "default_tags" {
  type = map
}

/* Name of the EKS cluster. */
variable "cluster_name" {
  type = string
}
