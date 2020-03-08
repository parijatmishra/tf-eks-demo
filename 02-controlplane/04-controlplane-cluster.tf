####################
# Log Group
####################

resource "aws_cloudwatch_log_group" "EksControlPlane" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
}

####################
# Cluster aka Control Plane
####################

resource "aws_eks_cluster" "EksControlPlane" {
  name     = var.cluster_name
  role_arn = aws_iam_role.EksControlPlane.arn

  enabled_cluster_log_types = [
    "api",
    # "audit",
    "authenticator",
    # "controllermanager",
    # "scheduler"
  ]

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    # security_group_ids      = [aws_security_group.EksControlPlane.id]
    subnet_ids = var.vpc_private_subnet_ids
  }


  depends_on = [
    aws_cloudwatch_log_group.EksControlPlane,
    aws_iam_role_policy_attachment.EksControlPlane-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.EksControlPlane-AmazonEKSServicePolicy,
    aws_iam_role_policy.EksAdditionalPermissions
  ]

  tags = merge({
    "Name" = var.cluster_name
  }, var.default_tags)

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --kubeconfig ${var.kubeconfig_path}"
  }
}
