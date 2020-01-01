resource "kubernetes_config_map" "auth-map" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    "mapRoles" = <<EOF
- rolearn: arn:aws:iam::838522581324:role/TfEksDemo-NodeGroup
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
EOF
  }
}
