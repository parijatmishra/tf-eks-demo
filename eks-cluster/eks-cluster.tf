provider "aws" {
  region = "us-east-1"
}

variable "default_tags" {
  type = map
}

variable "cluster-name" {
  type = string
}

variable "ssh_keypair_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_private_subnet_ids" {
  type = list(string)
}

########################################################################
# EKS Control Plane or "Cluster" - the master nodes
########################################################################

####################
# IAM
####################

resource "aws_iam_role" "EksControlPlane" {
  name        = "${var.cluster-name}-ControlPlane"
  description = "Allow Amazon EKS Control Plane access to our account resources"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge({
    "Name" = "${var.cluster-name}-ControlPlane"
  }, var.default_tags)
}

resource "aws_iam_role_policy_attachment" "EksControlPlane-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.EksControlPlane.name}"
}

resource "aws_iam_role_policy_attachment" "EksControlPlane-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.EksControlPlane.name}"
}

resource "aws_iam_role_policy" "EksCloudWatchMetricsPolicy" {
  name = "EksCloudWatchMetricsPolicy"
  role = "${aws_iam_role.EksControlPlane.name}"

  policy = <<EOF
{
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "cloudwatch:PutMetricData",
                "elasticloadbalancing:*",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:Describe*"
            ]
        }
    ]
}
EOF
}

####################
# Security Group
####################

resource "aws_security_group" "EksControlPlane" {
  name        = "${var.cluster-name}-ControlPlane"
  description = "Security Group for the EKS Masters"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    "Name" = "${var.cluster-name}ControlPlane"
  }, var.default_tags)
}

####################
# Log Group
####################

resource "aws_cloudwatch_log_group" "EksControlPlane" {
  name              = "/aws/eks/${var.cluster-name}/cluster"
  retention_in_days = 30
}

####################
# Cluster aka Control Plane
####################

resource "aws_eks_cluster" "EksControlPlane" {
  name = var.cluster-name

  version  = 1.14
  role_arn = aws_iam_role.EksControlPlane.arn
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    # "controllermanager",
    # "scheduler"
  ]

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.EksControlPlane.id]
    subnet_ids              = var.vpc_private_subnet_ids
  }


  depends_on = [
    "aws_cloudwatch_log_group.EksControlPlane",
    "aws_iam_role_policy_attachment.EksControlPlane-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.EksControlPlane-AmazonEKSServicePolicy",
    "aws_iam_role_policy.EksCloudWatchMetricsPolicy"
  ]

  tags = merge({
    "Name" = var.cluster-name
  }, var.default_tags)
}

########################################################################
# EKS Unmanaged Node Groups
########################################################################

####################
# IAM
####################

resource "aws_iam_role" "EksNodeGroup" {
  name        = "${var.cluster-name}-NodeGroup"
  description = "Allow EKS agent on worker nodes to call some AWS APIs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sts.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge({
    "Name" = "${var.cluster-name}-NodeGroup"
  }, var.default_tags)

}

#
# An IAM Instance Profile - needed for unmanaged Node Groups where we create
# our own EC2 instances
#
resource "aws_iam_instance_profile" "EksNodeGroupInstanceProfile" {
  name = "${var.cluster-name}-NodeGroup"
  role = "${aws_iam_role.EksNodeGroup.name}"
}

resource "aws_iam_role_policy_attachment" "EksNodeGroup-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.EksNodeGroup.name}"
}

resource "aws_iam_role_policy_attachment" "EksNodeGroup-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.EksNodeGroup.name}"
}

resource "aws_iam_role_policy_attachment" "EksNodeGroup-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.EksNodeGroup.name}"
}

resource "aws_iam_role_policy" "EksNodeGroup-EbsCsiDriverPolicy" {
  name = "${var.cluster-name}-NodeGroup-EbsCsiDriverPolicy"
  role = "${aws_iam_role.EksNodeGroup.name}"

  policy = <<EOF
{
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:AttachVolume",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteSnapshot",
                "ec2:DeleteTags",
                "ec2:DeleteVolume",
                "ec2:Describe*",
                "ec2:DetachVolume"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "EksNodeGroup-ALBIngressControllerPolicy" {
  name = "${var.cluster-name}-NodeGroup-ALBIngressControllerPolicy"
  role = "${aws_iam_role.EksNodeGroup.name}"

  policy = <<EOF
{
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "acm:DescribeCertificate",
                "acm:ListCertificates",
                "acm:GetCertificate",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:CreateTags",
                "ec2:DeleteTags",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:Describe*",
                "elasticloadbalancing:*",
                "iam:CreateServiceLinkedRole",
                "iam:GetServerCertificate",
                "iam:ListServerCertificates",
                "waf-regional:GetWebACLForResource",
                "waf-regional:GetWebACL",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "tag:GetResources",
                "tag:TagResources",
                "waf:GetWebACL"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "EksNodeGroup-ClusterAutoScalerPolicy" {
  name = "${var.cluster-name}-NodeGroup-ClusterAutoScalerPolicy"
  role = "${aws_iam_role.EksNodeGroup.name}"

  policy = <<EOF
{
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ]
        }
    ]
}
EOF
}

####################
# Security Group
####################

resource "aws_security_group" "EksNodeGroup" {
  name        = "${var.cluster-name}-NodeGroup"
  description = "Security Group for all EKS Worker Nodes"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    "Name"                                      = "${var.cluster-name}NodeGroup",
    "kubernetes.io/cluster/${var.cluster-name}" = "owned"
  }, var.default_tags)
}

resource "aws_security_group_rule" "EksNodeGroup-Ingress-Self" {
  description              = "Allow worker nodes to communicate with other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.EksNodeGroup.id
  source_security_group_id = aws_security_group.EksControlPlane.id
}

resource "aws_security_group_rule" "EksNodeGroup-Ingress-ControlPlane" {
  description              = "Allow worker nodes and kubelets to receive communication from EKS Control Plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.EksNodeGroup.id
  source_security_group_id = aws_security_group.EksControlPlane.id
}

#
# Update the Control Plane Security Group - add node security group to it
#
resource "aws_security_group_rule" "EksControlPlane-Ingress-NodeGroups" {
  description              = "Allow Control Plane to receive communication from pods and kubelets"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.EksControlPlane.id
  source_security_group_id = aws_security_group.EksNodeGroup.id
}


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

# User data to pass to the EC2 Instance. Calls built in EKS bootstrap.sh script
# See: https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh for the script source
# See: https://learn.hashicorp.com/terraform/aws/eks-intro#
# https://learn.hashicorp.com/terraform/aws/eks-intro#worker-node-autoscaling-group
# See: https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2019-11-15/amazon-eks-nodegroup.yaml
#      Resources -> NodeLaunchConfig -> Properties -> UserData
#   for an example of how to call it.
locals {
  userdata = <<EOF
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh '${var.cluster-name}'
EOF
}

####################
# Launch Template
####################

resource "aws_launch_template" "EksNodeGroup" {
  name = "${var.cluster-name}"

  iam_instance_profile {
    name = "${aws_iam_instance_profile.EksNodeGroupInstanceProfile.name}"
  }

  image_id               = data.aws_ssm_parameter.EksNodeGroupAmiId
  instance_type          = "t3a.medium"
  key_name               = var.ssh_keypair_name
  vpc_security_group_ids = ["${aws_security_group.EksNodeGroup.id}"]

  network_interfaces {
    associate_public_ip_address = false
  }

  user_data = base64encode(local.user_data)

  monitoring {
    enabled = true
  }
}

####################
# Auto Scaling Groups
####################
