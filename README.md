# Tailscale Subnet Router on AWS via Terraform

This project deploys a simple Tailscale Subnet Router on AWS using Terraform. It demonstrates how to securely access private AWS resources from any device on your Tailnet without opening inbound ports or configuring a VPN concentrator.

## Architecture Overview

![Architecture Diagram](architecture.png)

Architecture Summary:
- The Tailscale Subnet Router runs in a public subnet (10.0.1.0/24).
- A private EC2 instance runs in a private subnet (10.0.2.0/24).
- The router advertises both subnets to Tailscale.
- Any device on the same Tailnet (e.g., your laptop, phone) can securely reach the private subnet through the router.

## Prerequisites

1. Install required tools:
   - Terraform
   - AWS CLI

2. Configure AWS credentials using
```bash
   aws configure
```
5. Get a reusable Tailscale Auth Key from the Admin Console.

## Deployment Steps

1. Clone the repo:
```bash
   git clone https://github.com/priyankshah90/tailscale-subnet-router.git
   cd tailscale-subnet-router
```
3. Update terraform.tfvars with your AWS region, and Tailscale auth key.

4. Deploy:
```bash
   terraform init
   terraform apply -auto-approve
```
## Verification

After deployment, verify in the Tailscale Admin Console that your subnet router is online and routes are approved.

From your local system (in Tailnet):
``` bash
   tailscale ping 10.0.2.xx (Private IPv4 address of Private instance )
```   
Expected results:
   - tailscale ping → pong

## Project Structure

- main.tf - Defines AWS resources (VPC, subnets, EC2, Security Groups)
- variables.tf - Declares input variables
- terraform.tfvars - Sets variable values
- userdata.sh - Bootstraps Tailscale router
- .gitignore - Excludes Terraform state and secrets

## Cleanup

To delete all AWS resources:
``` bash
   terraform destroy -auto-approve
```
To reset Terraform working directory:
   rm -rf .terraform terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl

## Author

Priyank Shah
Networking & Cybersecurity Engineer | Cloud & Automation Enthusiast
Demonstrating secure, zero-trust AWS connectivity with Tailscale + Terraform.


