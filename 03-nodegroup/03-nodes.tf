####################
# AMI
####################

# Recommended EKS optimized AMI ID
data "aws_ssm_parameter" "EksNodeGroupAmiId" {
  name = "/aws/service/eks/optimized-ami/1.14/amazon-linux-2/recommended/image_id"
}

data "aws_region" "current" {}

####################
# User Data
####################

# User data to pass to the EC2 Instance. Calls built in EKS bootstrap.sh script in Amazon EKS AMI
# See: https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh for the script source
# You can also call it without --apiserver-endpoint and --b64-cluster-ca arguments, in which case
# it will lookup all EKS clusters using Describe* APIs, and find the one with the specified name,
# for getting the values for these arguments.

locals {
  userdata = <<EOF
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh \
  --apiserver-endpoint '${var.cluster_endpoint}' \
  --b64-cluster-ca '${var.cluster_certificate_authority_data}' \
  '${var.cluster_name}'
EOF
}

####################
# Launch Template
####################

resource "aws_launch_template" "EksNodeGroup-standard" {
  name = "${var.cluster_name}-NodeGroup-standard"

  iam_instance_profile {
    name = aws_iam_instance_profile.EksNodeGroupInstanceProfile.name
  }

  image_id               = data.aws_ssm_parameter.EksNodeGroupAmiId
  instance_type          = "t3a.medium"
  key_name               = var.ssh_keypair_name
  vpc_security_group_ids = [aws_security_group.EksNodeGroup.id]

  user_data = base64encode(local.userdata)

  monitoring {
    enabled = true
  }

  tags = merge({
    "Name" = "${var.cluster_name}-NodeGroup-standard"
  }, var.default_tags)

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      "Name" = "${var.cluster_name}-NodeGroup-standard"
    }, var.default_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      "Name" = "${var.cluster_name}-NodeGroup-standard"
    }, var.default_tags)
  }

}

####################
# Auto Scaling Groups - one per AZ so Cluster Autoscaler cannot work with ASGs that span AZs
# See: "Common Notes and Gotchas" at:
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
####################

resource "aws_autoscaling_group" "EksNodeGroup" {
  count = 3

  name     = "${var.cluster_name}-standard-${count.index}"
  min_size = 1
  max_size = 10

  launch_template {
    id      = aws_launch_template.EksNodeGroup-standard.id
    version = "$Latest"
  }

  default_cooldown    = 60
  health_check_type   = "EC2" # default
  vpc_zone_identifier = [var.vpc_private_subnet_ids[count.index]]

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
}
