####################
# Security Group
####################

resource "aws_security_group" "EksControlPlane" {
  name        = "${var.cluster_name}-ControlPlane"
  description = "Security Group for the EKS Masters"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    "Name" = "${var.cluster_name}ControlPlane"
  }, var.default_tags)
}
