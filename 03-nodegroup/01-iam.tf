####################
# IAM
####################

resource "aws_iam_role" "EksNodeGroup" {
  name        = "${var.cluster_name}-NodeGroup"
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
    "Name" = "${var.cluster_name}-NodeGroup"
  }, var.default_tags)
}

#
# An IAM Instance Profile - needed for unmanaged Node Groups where we create
# our own EC2 instances
#
resource "aws_iam_instance_profile" "EksNodeGroupInstanceProfile" {
  name = "${var.cluster_name}-NodeGroup"
  role = aws_iam_role.EksNodeGroup.name
}

resource "aws_iam_role_policy_attachment" "EksNodeGroup-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.EksNodeGroup.name
}

resource "aws_iam_role_policy_attachment" "EksNodeGroup-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.EksNodeGroup.name
}

resource "aws_iam_role_policy_attachment" "EksNodeGroup-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.EksNodeGroup.name
}

resource "aws_iam_role_policy" "EksNodeGroup-EbsCsiDriverPolicy" {
  name = "${var.cluster_name}-NodeGroup-EbsCsiDriverPolicy"
  role = aws_iam_role.EksNodeGroup.name

  policy = <<EOF
{
    "Version": "2012-10-17",
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
  name = "${var.cluster_name}-NodeGroup-ALBIngressControllerPolicy"
  role = aws_iam_role.EksNodeGroup.name

  policy = <<EOF
{
    "Version": "2012-10-17",
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
  name = "${var.cluster_name}-NodeGroup-ClusterAutoScalerPolicy"
  role = aws_iam_role.EksNodeGroup.name

  policy = <<EOF
{
    "Version": "2012-10-17",
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

