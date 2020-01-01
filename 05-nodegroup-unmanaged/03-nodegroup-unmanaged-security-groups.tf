
####################
# Security Group
####################

resource "aws_security_group" "NodeGroup" {
  name        = "${var.cluster_name}-ng"
  description = "Security Group for all EKS Worker Nodes"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    "Name"                                      = "${var.cluster_name}-ng",
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }, var.default_tags)
}

resource "aws_security_group_rule" "NodeGroup-Ingress-Self" {
  description              = "Allow worker nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.NodeGroup.id
  source_security_group_id = aws_security_group.NodeGroup.id
}

resource "aws_security_group_rule" "NodeGroup-Ingress-ControlPlane" {
  description              = "Allow worker nodes and kubelets to receive communication from EKS Control Plane"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.NodeGroup.id
  source_security_group_id = var.cluster_security_group_id
}

#
# Update the Control Plane Security Group - add node security group to it
#
resource "aws_security_group_rule" "EksControlPlane-Ingress-NodeGroups" {
  description              = "Allow Control Plane to receive communication from pods and kubelets"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.NodeGroup.id
}

#
# Allow incoming SSH
#
resource "aws_security_group_rule" "NodeGroup-Ingress-SSH" {
  count                    = length(var.allow_ssh_security_group_ids)
  description              = "Allow SSH into Node Group"
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.NodeGroup.id
  source_security_group_id = var.allow_ssh_security_group_ids[count.index]
}
