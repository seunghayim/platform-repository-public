data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "provisioner" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  key_name               = "langhae"
  vpc_security_group_ids = [aws_security_group.bastion-host.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  tags = {
    Name = "Bastuon-host-ec2"
  }
}

resource "null_resource" "provisioner" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = aws_instance.provisioner.id
    script      = filemd5("./files/kubectl-eksctl-cli.sh")
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./files/.ssh/id_rsa")
    host        = aws_instance.provisioner.public_ip
  }

  provisioner "file" {
    source      = "./files/.aws"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "./files/.ssh"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.aws ~/",
      "sudo mv /tmp/.ssh ~/"
    ]
  }

  provisioner "remote-exec" {
    script = "./files/kubectl-eksctl-cli.sh"
  }

  depends_on = [
    aws_eks_addon.ebs_cni,
    aws_eks_addon.coredns
  ]
}