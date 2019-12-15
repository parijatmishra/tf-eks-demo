output "nodegroup_iam_role_arn" {
  value = aws_iam_role.EksNodeGroup.arn
}

output "nodegroup_security_group_id" {
  value = aws_security_group.EksNodeGroup.id
}

output "nodegroup_launch_template_id" {
  value = aws_launch_template.EksNodeGroup-standard.id
}

output "nodegroup_asg_names" {
  value = aws_autoscaling_group.EksNodeGroup.*.name
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
    - rolearn: $NODEGROUP_IAM_ROLE_ARN
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAP
}
