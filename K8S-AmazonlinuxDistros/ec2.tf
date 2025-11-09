########################################
# AWS Provider Configuration
########################################
provider "aws" {
  region  = "us-east-1"
  profile = "meslek2002" # Ensure this profile exists in ~/.aws/credentials
}

########################################
# Data Source: Get All Available AZs
########################################
data "aws_availability_zones" "available_zones" {
  state = "available"
}

########################################
# Default VPC (creates if missing)
########################################
resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "default-vpc"
  }
}

########################################
# Default Subnet in the First AZ
########################################
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default-subnet"
  }
}

########################################
# Security Group for EC2 Instances
########################################
resource "aws_security_group" "ec2_security_group6" {
  name        = "ec2-security-group6"
  description = "Allow access on required ports"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort Range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-server-sg"
  }
}

########################################
# Data Source: Amazon Linux 2023 AMI (x86_64)
########################################
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

########################################
# EC2 Instances
########################################
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.medium"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group6.id]
  key_name               = "demolampkp"
  count                  = 3

  tags = {
    Name = "kubernetes-server-${count.index + 1}"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Downloads/demolampkp.pem")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "install_k8s.sh"
    destination = "/tmp/install_k8s.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install_k8s.sh",
      "sudo bash /tmp/install_k8s.sh"
    ]
  }
}

########################################
# Output
########################################
output "instance_public_ips" {
  description = "Public IPs of EC2 instances"
  value       = aws_instance.ec2_instance[*].public_ip
}
