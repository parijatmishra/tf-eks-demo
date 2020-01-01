output "nodegroup_iam_role_arn" {
  value = aws_iam_role.EksNodeGroup.arn
}
output "nodegroup_iam_instance_profile_arn" {
  value = aws_iam_instance_profile.EksNodeGroupInstanceProfile.arn
}

output "config_map" {
  value = <<CONFIGMAP
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.EksNodeGroup.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAP
}
