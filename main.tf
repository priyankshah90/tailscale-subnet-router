terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

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

data "aws_availability_zones" "available" {}

# -------------------------------
# VPC
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tailscale-vpc"
  }
}

# -------------------------------
# PUBLIC SUBNET
# -------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# -------------------------------
# PRIVATE SUBNET
# -------------------------------
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

# -------------------------------
# INTERNET GATEWAY
# -------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vpc-igw"
  }
}

# -------------------------------
# ROUTE TABLES
# -------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# PRIVATE ROUTE TABLE (no Internet route)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# -------------------------------
# SECURITY GROUP
# -------------------------------
resource "aws_security_group" "tailscale_sg" {
  name        = "tailscale-sg"
  description = "Allow internal traffic and Tailscale"
  vpc_id      = aws_vpc.main.id

  # Allow SSH only within VPC (no public access)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow UDP 41641 (Tailscale)
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tailscale-sg"
  }
}

# -------------------------------
# TAILSCALE SUBNET ROUTER (PUBLIC)
# -------------------------------
resource "aws_instance" "tailscale_router" {
  ami                    = data.aws_ami.ubuntu.id            
  instance_type          = var.instance_type                 
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.tailscale_sg.id]

  # IMPORTANT: render userdata with your auth key
  user_data = templatefile("${path.module}/userdata.sh", {
    tailscale_auth_key = var.tailscale_auth_key
  })

  tags = {
    Name = "tailscale-subnet-router"
  }
}

# -------------------------------
# PRIVATE EC2 INSTANCE
# -------------------------------
resource "aws_instance" "private_instance" {
  ami                         = data.aws_ami.ubuntu.id            
  instance_type               = var.instance_type                 
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.tailscale_sg.id]
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello from private instance" > /tmp/instance_info.txt
  EOF

  tags = {
    Name = "private-instance"
  }
}

# -------------------------------
# OUTPUTS
# -------------------------------
output "router_public_ip" {
  value = aws_instance.tailscale_router.public_ip
}

output "tailscale_instance_id" {
  value = aws_instance.tailscale_router.id
}

output "tailscale_instance_public_ip" {
  value = aws_instance.tailscale_router.public_ip
}

output "private_instance_id" {
  description = "Instance ID of the private EC2 instance"
  value       = aws_instance.private_instance.id
}

output "private_instance_subnet" {
  description = "Subnet ID of the private subnet"
  value       = aws_subnet.private.id
}
