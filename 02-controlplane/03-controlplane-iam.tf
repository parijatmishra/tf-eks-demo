resource "aws_iam_role" "EksControlPlane" {
  name        = "${var.cluster_name}-ControlPlane"
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
    "Name" = "${var.cluster_name}-ControlPlane"
  }, var.default_tags)
}

resource "aws_iam_role_policy_attachment" "EksControlPlane-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.EksControlPlane.name
}

resource "aws_iam_role_policy_attachment" "EksControlPlane-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.EksControlPlane.name
}

resource "aws_iam_role_policy" "EksAdditionalPermissions" {
  name = "${var.cluster_name}-EksAdditionalPermissions"
  role = aws_iam_role.EksControlPlane.name

  policy = <<EOF
{
    "Version": "2012-10-17",
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
