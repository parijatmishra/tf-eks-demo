resource "aws_iam_instance_profile" "bastion" {
  name = "${var.vpc_name}-bastion"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role" "bastion" {
  name               = "${var.vpc_name}-bastion"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.bastion_trust_policy.json
  tags               = merge({ "Name" = "${var.vpc_name}-bastion" }, var.default_tags)
}

data "aws_iam_policy_document" "bastion_trust_policy" {
  statement {
    sid = ""
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion.name
}

resource "aws_security_group" "bastion" {
  name        = "${var.vpc_name}-bastion"
  description = "Bastion security group (only SSH access)"
  vpc_id      = var.vpc_id
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({ "Name" = "${var.vpc_name}-bastion" }, var.default_tags)
}

data "template_file" "user_data" {
  template = file("user_data.sh")
  vars = {
    welcome_message = "This is ${var.vpc_name} Bastion"
  }
}

resource "aws_instance" "bastion" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.id
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = data.template_file.user_data.rendered

  tags = merge({ "Name" = "${var.vpc_name}-bastion" }, var.default_tags)
}
