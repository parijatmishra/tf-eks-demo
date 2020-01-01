output "nodegroup_security_group_id" {
  value = aws_security_group.NodeGroup.id
}

output "nodegroup_launch_template_id" {
  value = aws_launch_template.NodeGroup.id
}

output "nodegroup_asg_names" {
  value = aws_autoscaling_group.NodeGroup.*.name
}
