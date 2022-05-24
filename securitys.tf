data "aws_security_groups" "all" {}

################################################################################
# Security Groups for Control Plane 
################################################################################

resource "aws_security_group" "eks-cotrol-plane" {
  name        = "eks-control-plane-security_groups"
  description = "communication between nodes and the Kubernetes control plane."
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name                                  = "eks-control-plane-security-groups"
    "kubernetes.io/cluster/${local.name}" = "owned"
  }
}

################################################################################
# Security Groups for Node Groups
################################################################################

resource "aws_security_group" "node-groups" {
  name        = "eks-node-groups-security_groups"
  description = "communication between nodes and the Kubernetes control plane."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow node groups"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name                                  = "eks-node-groups-security-groups"
    "kubernetes.io/cluster/${local.name}" = "owned"
  }
}

################################################################################
# Security Groups for Bastion Host
################################################################################

resource "aws_security_group" "bastion-host" {
  name        = "basthion-host-ec2-security-groups"
  description = "communication between basthion host and the Kubernetes control plane."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "allow all"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "basthion-host-ec2-security-groups"
  }
}

################################################################################
# Add rule to the Control Plane
################################################################################

resource "aws_security_group_rule" "add-control-plane-ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cotrol-plane.id
  source_security_group_id = aws_security_group.bastion-host.id
}

resource "aws_security_group_rule" "add-control-plane-ingress1" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cotrol-plane.id
  source_security_group_id = aws_security_group.node-groups.id
}

resource "aws_security_group_rule" "add-control-plane-egress" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cotrol-plane.id
  source_security_group_id = aws_security_group.node-groups.id
}

################################################################################
# Add rule to the Node Groups
################################################################################

resource "aws_security_group_rule" "add-node-groups-ingress" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node-groups.id
  source_security_group_id = aws_security_group.eks-cotrol-plane.id
}

resource "aws_security_group_rule" "add-node-groups-ingress2" {
  type                     = "ingress"
  from_port                = 433
  to_port                  = 433
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node-groups.id
  source_security_group_id = aws_security_group.eks-cotrol-plane.id
}