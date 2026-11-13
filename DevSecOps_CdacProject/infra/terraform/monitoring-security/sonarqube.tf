###############################################################################
# Terraform Configuration
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

###############################################################################
# AWS Provider
###############################################################################

provider "aws" {
  region = "us-east-1"
}

###############################################################################
# Default VPC
###############################################################################

data "aws_vpc" "default" {
  default = true
}

###############################################################################
# Default Subnets
###############################################################################

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

###############################################################################
# Shared Security Group (SonarQube + DefectDojo + Wazuh)
###############################################################################

resource "aws_security_group" "devsecops_tools" {
  name_prefix = "devsecops-tools-"
  description = "Security Group for DevSecOps tooling EC2 instances (SonarQube, DefectDojo, Wazuh)"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "devsecops-tools-sg"
  }
}

###############################################################################
# Allow ALL Inbound Traffic
###############################################################################

resource "aws_vpc_security_group_ingress_rule" "devsecops_tools_ingress" {
  security_group_id = aws_security_group.devsecops_tools.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

###############################################################################
# Allow ALL Outbound Traffic
###############################################################################

resource "aws_vpc_security_group_egress_rule" "devsecops_tools_egress" {
  security_group_id = aws_security_group.devsecops_tools.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

###############################################################################
# SonarQube EC2 Instance
###############################################################################

resource "aws_instance" "sonarqube" {
  ami           = "ami-0f8a61b66d1accaee"
  instance_type = "t3.large"
  key_name      = "eks-key"

  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [
    aws_security_group.devsecops_tools.id
  ]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "sonarqube-server"
    Role = "SonarQube"
  }
}

###############################################################################
# DefectDojo EC2 Instance
###############################################################################

resource "aws_instance" "defectdojo" {
  ami           = "ami-0f8a61b66d1accaee"
  instance_type = "t3.large"
  key_name      = "eks-key"

  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [
    aws_security_group.devsecops_tools.id
  ]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "defectdojo-server"
    Role = "DefectDojo"
  }
}

###############################################################################
# Wazuh EC2 Instance (Manager + Indexer + Dashboard, single-node Docker stack)
###############################################################################

resource "aws_instance" "wazuh" {
  ami           = "ami-0f8a61b66d1accaee"
  instance_type = "t3.large"
  key_name      = "eks-key"

  subnet_id = data.aws_subnets.default.ids[0]

  vpc_security_group_ids = [
    aws_security_group.devsecops_tools.id
  ]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "wazuh-server"
    Role = "Wazuh"
  }
}

###############################################################################
# Outputs
###############################################################################

output "sonarqube_public_ip" {
  description = "Public IP of SonarQube EC2"
  value       = aws_instance.sonarqube.public_ip
}

output "sonarqube_public_dns" {
  description = "Public DNS of SonarQube EC2"
  value       = aws_instance.sonarqube.public_dns
}

output "defectdojo_public_ip" {
  description = "Public IP of DefectDojo EC2"
  value       = aws_instance.defectdojo.public_ip
}

output "defectdojo_public_dns" {
  description = "Public DNS of DefectDojo EC2"
  value       = aws_instance.defectdojo.public_dns
}

output "wazuh_public_ip" {
  description = "Public IP of Wazuh EC2"
  value       = aws_instance.wazuh.public_ip
}

output "wazuh_public_dns" {
  description = "Public DNS of Wazuh EC2"
  value       = aws_instance.wazuh.public_dns
}

output "devsecops_tools_sg_id" {
  description = "Shared security group ID for SonarQube/DefectDojo/Wazuh - used to scope Wazuh agent ingress to the EKS NAT Gateway IP"
  value       = aws_security_group.devsecops_tools.id
}
