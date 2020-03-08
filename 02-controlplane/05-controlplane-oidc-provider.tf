/* AWS IAM OIDC Connect Provider: needed to connect Kubernetes Service Accounts with AWS IAM.
 * See: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
 * See: https://medium.com/@marcincuber/amazon-eks-with-oidc-provider-iam-roles-for-kubernetes-services-accounts-59015d15cb0c
 */

data "external" "thumbprint" {
  program = ["./05-controlplane-oidc-provider-thumbprint.sh", data.aws_region.current.name]
}
resource "aws_iam_openid_connect_provider" "EksControlPlane" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.EksControlPlane.identity.0.oidc.0.issuer
}
