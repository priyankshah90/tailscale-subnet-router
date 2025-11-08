variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "tailscale_auth_key" {
  description = "Reusable or ephemeral Tailscale auth key"
  type        = string
  sensitive   = true
}