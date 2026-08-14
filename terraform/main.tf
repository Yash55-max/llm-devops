terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetch the deployer's public IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# Find latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "llm-serving-key"
  public_key = file(var.public_key_path)
}

# Security Group restricted to your IP
resource "aws_security_group" "llm_sg" {
  name        = "llm-serving-sg"
  description = "Allow inbound SSH and FastAPI traffic from deployer IP only"

  ingress {
    description = "SSH from local IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  ingress {
    description = "FastAPI Port 8000 from local IP"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "llm-serving-sg"
  }
}

# EC2 Instance
resource "aws_instance" "llm_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.llm_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 25 # GB, to comfortably host Docker & Ollama weights
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "llm-serving-node"
    Project = "llm-devops"
  }
}