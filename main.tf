locals {
  name            = "multi05-eks-cluster-terraform"
  cluster_version = "1.22"
  region          = "ap-southeast-2"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }

}

resource "aws_eks_cluster" "this" {
  name     = local.name
  role_arn = aws_iam_role.eks.arn
  version  = local.cluster_version

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = concat(module.vpc.private_subnets, module.vpc.public_subnets)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks-cotrol-plane.id]
    # public_access_cidrs     = [cidrsubnet(aws_instance.provisioner.public_ip, 16)]
  }

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
  }

  # encryption_config {
  #   provider {
  #     key_arn = aws_kms_key.eks.arn
  #   }
  #   resources = ["secrets"]
  # }

  depends_on = [
    aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController,
    module.vpc
  ]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "vpc-cni"
  resolve_conflicts        = "OVERWRITE"
  addon_version            = "v1.11.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.cni.arn
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "kube-proxy"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
  depends_on        = [aws_eks_node_group.node]
}

# resource "aws_eks_addon" "ebs_cni" {
#   cluster_name             = aws_eks_cluster.this.name
#   addon_name               = "aws-ebs-csi-driver"
#   resolve_conflicts        = "OVERWRITE"
#   service_account_role_arn = aws_iam_role.ebs_csi.arn
#   depends_on               = [aws_eks_node_group.node]
# }

# resource "aws_cloudwatch_log_group" "eks" {
#   name              = "/aws/eks/${local.name}/cluster"
#   retention_in_days = 7
# }

# resource "aws_kms_key" "eks" {
#   description             = "EKS KMS"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true

#   tags = local.tags
# }