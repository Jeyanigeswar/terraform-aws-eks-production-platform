# Terraform AWS EKS Production Platform

Production-grade AWS infrastructure deployment using Terraform.

## Architecture

- Amazon VPC
- Public & Private Subnets
- Amazon EKS
- Amazon RDS PostgreSQL
- Application Load Balancer
- Route53
- ACM SSL Certificates
- GitHub Actions CI/CD

## Features

- Infrastructure as Code
- Modular Terraform Design
- Multi-AZ Architecture
- Remote State Management
- Auto Scaling
- Monitoring and Logging

## Technology Stack

Terraform
AWS
Kubernetes
Docker
GitHub Actions
Prometheus
Grafana

## Repository Structure

terraform/
kubernetes/
docs/
architecture/

## IAM Architecture

### EKS Cluster Role

Responsible for:

- Cluster management
- Kubernetes control plane integration
- AWS API communication

### EKS Node Group Role

Responsible for:

- EC2 worker nodes
- Pulling images from ECR
- VPC networking via CNI

## Amazon EKS

### Features

- Managed Kubernetes Control Plane
- Managed Node Groups
- VPC CNI
- CoreDNS
- Kube Proxy
- Auto Scaling Ready

### Kubernetes Resources

- Deployment
- Service
- Ingress