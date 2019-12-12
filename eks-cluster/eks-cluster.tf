provider "aws" {
  region = "us-east-1"
}

variable "default_tags" {
  type = map
}

variable "cluster-name" {
  type = string
}

variable "keypair" {
  type = string
}

variable "vpc_id" {
  type = string
}

resource "aws_iam_role" "EksServiceRole" {
  name        = "${var.cluster-name}ServiceRole"
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
    "Name" = "${var.cluster-name}ServiceRole"
  }, var.default_tags)
}

resource "aws_iam_role_policy_attachment" "EksServiceRole-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.EksServiceRole.name}"
}

resource "aws_iam_role_policy_attachment" "EksServiceRole-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.EksServiceRole.name}"
}

resource "aws_iam_role_policy" "EksCloudWatchMetricsPolicy" {
  name = "EksCloudWatchMetricsPolicy"
  role = "${aws_iam_role.EksServiceRole.name}"

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

resource "aws_iam_role" "EksNodeGroupRole" {
  name        = "${var.cluster-name}NodeGroupRole"
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
    "Name" = "${var.cluster-name}NodeGroupRole"
  }, var.default_tags)

}

resource "aws_iam_role_policy_attachment" "EksNodeGroupRole-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.EksNodeGroupRole.name}"
}

resource "aws_iam_role_policy_attachment" "EksNodeGroupRole-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.EksNodeGroupRole.name}"
}

resource "aws_iam_role_policy_attachment" "EksNodeGroupRole-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.EksNodeGroupRole.name}"
}

resource "aws_iam_role_policy" "EksNodeGroupRole-EbsCsiDriverPolicy" {
  name = "${var.cluster-name}-NodeGroup-EbsCsiDriverPolicy"
  role = "${aws_iam_role.EksNodeGroupRole.name}"

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

resource "aws_iam_role_policy" "EksNodeGroupRole-ALBIngressControllerPolicy" {
  name = "${var.cluster-name}-NodeGroup-ALBIngressControllerPolicy"
  role = "${aws_iam_role.EksNodeGroupRole.name}"

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

resource "aws_iam_role_policy" "EksNodeGroupRole-ClusterAutoScalerPolicy" {
  name = "${var.cluster-name}-NodeGroup-ClusterAutoScalerPolicy"
  role = "${aws_iam_role.EksNodeGroupRole.name}"

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

resource "aws_security_group" "EksControlPlane" {
  name        = "${var.cluster-name}ControlPlane"
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

resource "aws_security_group" "EksNodeGroup" {
  name        = "${var.cluster-name}NodeGroup"
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

resource "aws_security_group_rule" "EksControlPlane-Ingress-NodeGroups" {
  description              = "Allow Control Plane to receive communication from pods and kubelets"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.EksControlPlane.id
  source_security_group_id = aws_security_group.EksNodeGroup.id
}
