################################################################################
# create_eks_role_policy
################################################################################

resource "aws_iam_role" "eks" {
  name = "${local.name}-iam-role"

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
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "eks_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks.name
}


################################################################################
# IAM Role for EKS Addon "vpc-cni" with AWS managed policy
################################################################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cni" {
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
  name               = "${local.name}-vpc-cni-role"
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cni.name
}

################################################################################
# IAM Role for node_groups
################################################################################

resource "aws_iam_role" "node" {
  name = "${local.name}-node-groups-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "externalDNS" {
  name        = "${local.name}-external-DNS-policy"
  description = "My custom external DNS policy"

  policy = file("${path.module}/policy/externalDNS.json")
}

resource "aws_iam_role_policy_attachment" "node_externalDNSPolicy" {
  policy_arn = aws_iam_policy.externalDNS.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryPowerUser" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node.name
}

################################################################################
# IAM Role for Bastion host
################################################################################

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${local.name}-bastion-host-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role" "bastion" {
  name = "${local.name}-bastion-host-iam-role"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

################################################################################
# IAM Role for Ingress controller
################################################################################

data "aws_iam_policy_document" "ingress_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "ingress_controller_policy" {
  name        = "${local.name}-ingress-controller-policy"
  description = "My custom ingress controller policy"

  policy = file("${path.module}/policy/ingress_iam_policy.json")
}

resource "aws_iam_role" "ingress_controller" {
  assume_role_policy = data.aws_iam_policy_document.ingress_controller_assume_role_policy.json
  name               = "${local.name}-ingress-controller-role"
}

resource "aws_iam_role_policy_attachment" "ingress_controller" {
  policy_arn = aws_iam_policy.ingress_controller_policy.arn
  role       = aws_iam_role.ingress_controller.name
}

################################################################################
# IAM Role for Autuscaling
################################################################################

data "aws_iam_policy_document" "autoscaling_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name        = "${local.name}-autoscaler-policy"
  description = "My custom cluster autoscaler policy"

  policy = file("${path.module}/policy/cluster-autoscaler-policy.json")
}

resource "aws_iam_role" "cluster_autoscaler" {
  assume_role_policy = data.aws_iam_policy_document.autoscaling_assume_role_policy.json
  name               = "${local.name}-autoscaler-role"
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

################################################################################
# IAM Role for EBS CSI Driver
################################################################################

data "aws_iam_policy_document" "ebs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "${local.name}-ebs-csi-policy"
  description = "My custom ebs csi policy"

  policy = file("${path.module}/policy/ebs-csi-iam-policy.json")
}

resource "aws_iam_role" "ebs_csi" {
  assume_role_policy = data.aws_iam_policy_document.ebs_assume_role_policy.json
  name               = "${local.name}-ebs-csi-role"
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = aws_iam_policy.ebs_csi_policy.arn
  role       = aws_iam_role.ebs_csi.name
}


################################################################################
# IAM Role for EFS CSI Driver
################################################################################

data "aws_iam_policy_document" "efs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_policy" "efs_csi_policy" {
  name        = "${local.name}-efs-csi-policy"
  description = "My custom efs csi policy"

  policy = file("${path.module}/policy/ebs-csi-iam-policy.json")
}

resource "aws_iam_role" "efs_csi" {
  assume_role_policy = data.aws_iam_policy_document.efs_assume_role_policy.json
  name               = "${local.name}-efs-csi-role"
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  policy_arn = aws_iam_policy.efs_csi_policy.arn
  role       = aws_iam_role.efs_csi.name
}

################################################################################
# IAM Role for cloudwatch-agent
################################################################################

# data "aws_iam_policy_document" "cloudwatch_agent_policy" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
#     }

#     principals {
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#       type        = "Federated"
#     }
#   }
# }

# resource "aws_iam_role" "cloudwatch_agent" {
#   assume_role_policy = data.aws_iam_policy_document.cloudwatch_agent_policy.json
#   name               = "${local.name}-cloudwatch-agent-role"
# }


# resource "aws_iam_role_policy_attachment" "cloudwatch_agent_CloudWatchAgentServerPolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
#   role       = aws_iam_role.cloudwatch_agent.name
# }

################################################################################
# IAM Role for fluent-bit
################################################################################

# data "aws_iam_policy_document" "fluent_bit_policy" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:amazon-cloudwatch:fluent-bit"]
#     }

#     principals {
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#       type        = "Federated"
#     }
#   }
# }

# resource "aws_iam_role" "fluent_bit" {
#   assume_role_policy = data.aws_iam_policy_document.fluent_bit_policy.json
#   name               = "${local.name}-fluent-bit-role"
# }


# resource "aws_iam_role_policy_attachment" "fluent_bit_CloudWatchAgentServerPolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
#   role       = aws_iam_role.fluent_bit.name
# }

################################################################################
# IAM Role for prometheus
################################################################################

data "aws_iam_policy_document" "cwagent_prometheus_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cwagent-prometheus"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cwagent_prometheus" {
  assume_role_policy = data.aws_iam_policy_document.cwagent_prometheus_policy.json
  name               = "${local.name}-cwagent-prometheus-role"
}


resource "aws_iam_role_policy_attachment" "cwagent_prometheus_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cwagent_prometheus.name
}

################################################################################
# IAM Role for XRay Trace
################################################################################

# data "aws_iam_policy_document" "xray_daemon" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:default:xray-daemon"]
#     }

#     principals {
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#       type        = "Federated"
#     }
#   }
# }

# resource "aws_iam_role" "xray_daemon" {
#   assume_role_policy = data.aws_iam_policy_document.xray_daemon.json
#   name               = "${local.name}-xray-daemon-role"
# }


# resource "aws_iam_role_policy_attachment" "xray_daemon_AWSXRayDaemonWriteAccess" {
#   policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
#   role       = aws_iam_role.xray_daemon.name
# }
