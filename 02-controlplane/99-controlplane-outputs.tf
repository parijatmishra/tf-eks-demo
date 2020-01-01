output "cluster_id" {
  value = aws_eks_cluster.EksControlPlane.id
}

output "cluster_k8s_version" {
  value = aws_eks_cluster.EksControlPlane.version
}

output "cluster_platform_version" {
  value = aws_eks_cluster.EksControlPlane.platform_version
}

output "cluster_arn" {
  value = aws_eks_cluster.EksControlPlane.arn
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.EksControlPlane.certificate_authority
}

output "cluster_endpoint" {
  value = aws_eks_cluster.EksControlPlane.endpoint
}

output "cluster_identity" {
  value = aws_eks_cluster.EksControlPlane.identity
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.EksControlPlane.vpc_config[0].cluster_security_group_id
}
