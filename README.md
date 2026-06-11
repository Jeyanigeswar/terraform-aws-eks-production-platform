# terraform-aws-eks-production-platform

[![Terraform Plan](https://github.com/Jeyanigeswar/terraform-aws-eks-production-platform/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/Jeyanigeswar/terraform-aws-eks-production-platform/actions/workflows/terraform-plan.yml)
[![Terraform Apply](https://github.com/Jeyanigeswar/terraform-aws-eks-production-platform/actions/workflows/terraform-apply.yml/badge.svg)](https://github.com/Jeyanigeswar/terraform-aws-eks-production-platform/actions/workflows/terraform-apply.yml)
[![Terraform](https://img.shields.io/badge/Terraform-≥1.6-7B42BC?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io)
[![AWS EKS](https://img.shields.io/badge/EKS-1.29-FF9900?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![License: MIT](https://img.shields.io/badge/License-MIT-22c55e?style=flat)](LICENSE)

Production-grade AWS infrastructure provisioned with modular Terraform.
Deploys a complete EKS platform — VPC, EKS cluster, RDS PostgreSQL,
Application Load Balancer, and ACM SSL — across isolated dev, staging,
and production environments from a single reusable module library.

Remote state is stored in S3 with DynamoDB locking. All environments
are deployed and validated via GitHub Actions CI/CD.

---

## Architecture

```
                        Internet
                           │
              ┌────────────▼────────────┐
              │   Application Load      │
              │   Balancer (HTTPS/443)  │
              │   ACM SSL Terminated    │
              └────────────┬────────────┘
                           │
    ┌──────────────────────▼──────────────────────┐
    │              VPC  10.x.0.0/16               │
    │                                             │
    │  ┌─────────────────────────────────────┐   │
    │  │         Public Subnets (3 AZ)        │   │
    │  │     NAT Gateways  ·  IGW Route       │   │
    │  └──────────────────┬──────────────────┘   │
    │                     │ (private egress)      │
    │  ┌──────────────────▼──────────────────┐   │
    │  │        Private Subnets (3 AZ)        │   │
    │  │    EKS Worker Nodes (t3/m5 fleet)    │   │
    │  │    HPA · RBAC · IMDSv2 required      │   │
    │  └──────────────────┬──────────────────┘   │
    │                     │ (no internet route)   │
    │  ┌──────────────────▼──────────────────┐   │
    │  │       Database Subnets (3 AZ)        │   │
    │  │   RDS PostgreSQL 15  ·  Multi-AZ     │   │
    │  │   KMS encrypted  ·  7-day backups    │   │
    │  └─────────────────────────────────────┘   │
    │                                             │
    │  VPC Flow Logs → CloudWatch                 │
    └─────────────────────────────────────────────┘

    Supporting services:
    Route53 DNS  ·  ACM Certificate  ·  AWS Secrets Manager
    ECR (container registry)  ·  CloudWatch  ·  IAM / IRSA
```

---

## What this repo deploys

| Module | Resources | Notes |
|---|---|---|
| `modules/vpc` | VPC, public/private/database subnets, NAT GW, IGW, flow logs | `single_nat_gateway = true` for dev/staging saves ~$32/mo |
| `modules/eks` | EKS 1.29 cluster, managed node groups, OIDC provider, add-ons, KMS | IMDSv2 enforced on all nodes |
| `modules/rds` | RDS PostgreSQL 15 Multi-AZ, subnet group, parameter group, alarms | Deletion protection enabled in prod |
| `modules/alb` | Application Load Balancer, HTTP→HTTPS redirect, target group | Access logs to S3 |
| `modules/iam` | Cluster role, node role, IRSA factory | Least-privilege policies |
| `modules/acm` | ACM certificate with Route53 DNS validation | Wildcard + apex cert |

---

## Repository structure

```
.
├── modules/
│   ├── vpc/          # VPC, subnets, NAT, flow logs
│   ├── eks/          # EKS cluster, node groups, OIDC, add-ons
│   ├── rds/          # RDS PostgreSQL Multi-AZ
│   ├── alb/          # Application Load Balancer + HTTPS
│   ├── iam/          # Cluster/node roles + IRSA factory
│   └── acm/          # ACM certificate + Route53 validation
├── environments/
│   ├── dev/          # Single NAT, t3.medium nodes, db.t3.micro
│   ├── staging/      # Single NAT, t3.large nodes, db.t3.medium
│   └── prod/         # Per-AZ NAT, m5.xlarge nodes, db.r6g.large
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml   # Runs on every PR
│       └── terraform-apply.yml  # Runs on merge to main
└── scripts/
    └── bootstrap-backend.sh     # Creates S3 + DynamoDB for state
```

Each module contains `main.tf`, `variables.tf`, `outputs.tf`, and `README.md`.
Each environment contains `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`,
and `terraform.tfvars`.

---

## Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| Terraform | 1.6.0 | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| kubectl | 1.29 | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.x | [helm.sh](https://helm.sh/docs/intro/install/) |

AWS credentials must be configured with permissions to create VPC, EKS, RDS, IAM, ALB,
Route53, and ACM resources.

---

## Quick start

### Step 1 — Bootstrap remote state (run once per environment)

```bash
chmod +x scripts/bootstrap-backend.sh
./scripts/bootstrap-backend.sh dev ap-south-1
```

This creates an S3 bucket (`aws-eks-platform-tfstate-dev-<account-id>`) with versioning
and KMS encryption, and a DynamoDB table (`aws-eks-platform-tflock-dev`) for state locking.

### Step 2 — Deploy dev environment

```bash
cd environments/dev

# Initialise with remote backend
terraform init

# Review what will be created (~60 resources)
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

Expected apply time: ~15 minutes (EKS cluster creation dominates).

### Step 3 — Configure kubectl

```bash
aws eks update-kubeconfig \
  --name eks-platform-dev \
  --region ap-south-1

kubectl get nodes
```

### Deploying staging and production

```bash
# Staging
cd environments/staging && terraform init && terraform apply

# Production — review carefully before applying
cd environments/prod && terraform init && terraform plan -out=tfplan
terraform apply tfplan
```

---

## Environment comparison

| Setting | dev | staging | prod |
|---|---|---|---|
| NAT Gateways | 1 (cost saving) | 1 (cost saving) | 3 (one per AZ) |
| EKS node type | t3.medium | t3.large | m5.xlarge |
| EKS min/max nodes | 1 / 3 | 2 / 5 | 3 / 10 |
| RDS instance | db.t3.micro | db.t3.medium | db.r6g.large |
| RDS Multi-AZ | ✗ | ✓ | ✓ |
| Deletion protection | ✗ | ✗ | ✓ |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |

---

## Module reference

### `modules/vpc`

| Input | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Name prefix for all resources |
| `vpc_cidr` | string | — | VPC CIDR block |
| `availability_zones` | list(string) | — | AZs to span |
| `public_subnet_cidrs` | list(string) | — | One per AZ |
| `private_subnet_cidrs` | list(string) | — | One per AZ |
| `database_subnet_cidrs` | list(string) | — | One per AZ |
| `cluster_name` | string | — | EKS cluster name (for subnet tags) |
| `single_nat_gateway` | bool | `false` | `true` = cost-saving single NAT |
| `flow_log_retention_days` | number | `30` | CloudWatch log retention |

| Output | Description |
|---|---|
| `vpc_id` | VPC resource ID |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `database_subnet_ids` | List of database subnet IDs |

---

### `modules/eks`

| Input | Type | Default | Description |
|---|---|---|---|
| `cluster_name` | string | — | EKS cluster name |
| `kubernetes_version` | string | `"1.29"` | Kubernetes version |
| `vpc_id` | string | — | VPC to deploy into |
| `private_subnet_ids` | list(string) | — | Subnets for node groups |
| `cluster_role_arn` | string | — | IAM role ARN for cluster |
| `node_role_arn` | string | — | IAM role ARN for node groups |
| `node_groups` | map(object) | see below | Node group definitions |
| `endpoint_public_access` | bool | `true` | Expose API endpoint publicly |

**`node_groups` object schema:**
```hcl
node_groups = {
  system = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 1
    max_size       = 3
    disk_size      = 50
    labels         = {}
    taints         = []
  }
}
```

| Output | Description |
|---|---|
| `cluster_endpoint` | EKS API server endpoint |
| `cluster_ca_certificate` | Base64-encoded CA certificate |
| `oidc_provider_arn` | OIDC provider ARN (for IRSA) |
| `node_security_group_id` | Security group ID for worker nodes |

---

### `modules/rds`

| Input | Type | Default | Description |
|---|---|---|---|
| `identifier` | string | — | RDS instance identifier |
| `engine_version` | string | `"15.4"` | PostgreSQL version |
| `instance_class` | string | — | e.g. `db.t3.micro` |
| `multi_az` | bool | `false` | Enable Multi-AZ standby |
| `deletion_protection` | bool | `false` | Prevent accidental deletion |
| `database_subnet_ids` | list(string) | — | Subnets for subnet group |
| `allowed_security_group_ids` | list(string) | — | SGs allowed to connect on 5432 |

| Output | Description |
|---|---|
| `endpoint` | RDS connection endpoint |
| `port` | Database port (5432) |
| `db_name` | Database name |

---

## CI/CD pipeline

Every pull request targeting `main` triggers `terraform-plan.yml`:

```
PR opened / updated
       │
       ├── terraform fmt --check     (fails on unformatted code)
       ├── terraform validate        (syntax + provider check)
       ├── trivy config scan         (IaC security scanning)
       └── terraform plan            (plan output posted as PR comment)

PR merged to main
       │
       └── terraform apply           (auto-apply to dev environment)
                                     (staging and prod require manual approval)
```

**Required GitHub secrets:**

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key with deploy permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AWS_REGION` | Target region (e.g. `ap-south-1`) |

---

## Security features

- **KMS encryption** — EKS secrets and RDS storage encrypted at rest
- **IMDSv2 required** — All EC2 nodes enforce instance metadata service v2
- **Least-privilege IAM** — Separate cluster and node roles; IRSA for pod-level access
- **No hardcoded secrets** — All credentials via AWS Secrets Manager
- **VPC Flow Logs** — All VPC traffic logged to CloudWatch
- **Private node groups** — Worker nodes have no direct internet exposure
- **Database isolation** — RDS in dedicated subnets with no internet route
- **Trivy IaC scanning** — Security checks run on every pull request

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Make changes and commit with conventional commits:
   ```
   feat(vpc): add support for IPv6 CIDR blocks
   fix(eks): pin coredns addon version to avoid drift
   docs(rds): add recovery point objective to README
   ```
4. Run `terraform fmt` and `terraform validate` before pushing
5. Open a pull request — the plan will run automatically

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

*Built by [Jeyanigeswar R](https://github.com/Jeyanigeswar) · Cloud Engineer at HCL Technologies*