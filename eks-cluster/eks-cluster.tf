provider "aws" {
  region = "us-east-1"
}

variable "cluster-name" {
  type = string
}

resource "aws_iam_role" "EksServiceRole" {
  name = "${var.cluster-name}Role"

  assume_role_policy = <<POLICY
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
POLICY

  tags = {
    Application = "EksClusterTf"
    Environment = "dev"
  }
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
  role = "${aws_iam_role.EksServiceRole}"

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

