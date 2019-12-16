
####################
# Security Group
####################

resource "aws_security_group" "EksNodeGroup" {
  name        = "${var.cluster_name}-NodeGroup"
  description = "Security Group for all EKS Worker Nodes"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    "Name"                                      = "${var.cluster_name}-NodeGroup",
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }, var.default_tags)
}

resource "aws_security_group_rule" "EksNodeGroup-Ingress-Self" {
  description              = "Allow worker nodes to communicate with other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.EksNodeGroup.id
  source_security_group_id = var.cluster_security_group_id
}

resource "aws_security_group_rule" "EksNodeGroup-Ingress-ControlPlane" {
  description              = "Allow worker nodes and kubelets to receive communication from EKS Control Plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.EksNodeGroup.id
  source_security_group_id = var.cluster_security_group_id
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
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.EksNodeGroup.id
}
