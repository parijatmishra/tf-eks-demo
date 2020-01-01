####################
# AMI
####################

# Recommended EKS optimized AMI ID
data "aws_ssm_parameter" "EksAMIID" {
  name = "/aws/service/eks/optimized-ami/1.14/amazon-linux-2/recommended/image_id"
}

data "aws_region" "current" {}

####################
# User Data
####################

# User data to pass to the EC2 Instance. Calls built in EKS bootstrap.sh script in Amazon EKS AMI
# See: https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh for the script source.
# You can also call it with --apiserver-endpoint and --b64-cluster-ca arguments, in which case
# it will skip looking up EKS Clusters and finding the one with the specified
# name.

locals {
  userdata = <<EOF
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh '${var.cluster_name}'
EOF

  /* Convert the `default_tags` map to a list of maps expected by
   * the aws_autoscaling_group.tags field, and add more required tags.
   */
  asg_tags = concat(
    /* `default_tags` */
    [for k, v in var.default_tags : { "key" : k, "value" : v, "propagate_at_launch" : true }],
    [
      /* Needed by Cluster Auto Scaler */
      {
        "key" : "kubernetes.io/cluster/${var.cluster_name}",
        "value" : "owned",
        "propagate_at_launch" : true
      },
      /* Not required as ASGs have an in-built name, but for consistency */
      {
        "key" : "Name",
        "value" : "${var.cluster_name}-ng",
        "propagate_at_launch" : false /* Launch Template has its own `Name` */
      }
    ]
  )
}

####################
# Launch Template
####################
resource "aws_launch_template" "NodeGroup" {
  name = "${var.cluster_name}-ng"

  iam_instance_profile {
    arn = var.nodegroup_iam_instance_profile_arn
  }

  image_id               = data.aws_ssm_parameter.EksAMIID.value
  instance_type          = var.instance_type
  key_name               = var.ssh_keypair_name
  vpc_security_group_ids = [aws_security_group.NodeGroup.id]

  user_data = base64encode(local.userdata)

  monitoring {
    enabled = true
  }

  tags = merge({
    "Name" = "${var.cluster_name}-ng"
  }, var.default_tags)

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      "Name" = "${var.cluster_name}-ng",
    }, var.default_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      "Name" = "${var.cluster_name}-ng"
    }, var.default_tags)
  }

}

####################
# Auto Scaling Groups - one per AZ so Cluster Autoscaler cannot work with ASGs that span AZs
# See: "Common Notes and Gotchas" at:
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
####################

resource "aws_autoscaling_group" "NodeGroup" {
  count = length(var.vpc_private_subnet_ids)

  name     = "${var.cluster_name}-ng-${count.index}"
  min_size = 1
  max_size = 10

  launch_template {
    id      = aws_launch_template.NodeGroup.id
    version = "$Latest"
  }

  default_cooldown          = 60
  health_check_type         = "EC2" # default
  health_check_grace_period = 0
  vpc_zone_identifier       = [var.vpc_private_subnet_ids[count.index]]

  # See: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-instance-monitoring.html
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  tags = local.asg_tags
}
