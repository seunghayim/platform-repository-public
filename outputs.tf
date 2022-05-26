output "endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "tls-certificate" {
  value = data.tls_certificate.eks
}

output "aws-iam-policy-document-vpc-cni" {
  value = data.aws_iam_policy_document.eks_assume_role_policy
}

output "aws-iam-policy-document-ingress" {
  value = data.aws_iam_policy_document.ingress_controller_assume_role_policy
}


output "aws-availability-zone" {
  value = data.aws_availability_zones.available
}

output "aws_security_groups" {
  value = data.aws_security_groups.all
}

output "provisioner_instance" {
  value = {
    public_ip   = aws_instance.provisioner.public_ip
    public_dns  = aws_instance.provisioner.public_dns
    private_ip  = aws_instance.provisioner.private_ip
    private_dns = aws_instance.provisioner.private_dns
  }
}

output "aws_ami_version" {
  value = data.aws_ami.eks_default
}

output "aws_ingress_controller_iam_role" {
  value = aws_iam_role.ingress_controller
}

output "aws_cluster_autoscaler_iam_role" {
  value = aws_iam_role.cluster_autoscaler
}

output "aws_ebs_csi_iam_role" {
  value = aws_iam_role.ebs_csi
}

output "aws_efs_csi_iam_role" {
  value = aws_iam_role.efs_csi
}

output "aws_prometheus_iam_role" {
  value = aws_iam_role.cwagent_prometheus
}

output "aws_ami_latest_version" {
  value = data.aws_ami.eks_default
}