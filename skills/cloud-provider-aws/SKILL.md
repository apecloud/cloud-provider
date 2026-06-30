---
name: cloud-provider-aws
description: Guide maintaining AWS Terraform modules in the cloud-provider repository. Trigger when modifying, adding, or reviewing EKS (eks, eks-default-vpc, eks-default-vpc-api/dj/multinode/test, eks-autoscaling) and LB resources, variables, run.sh, and versions.tf under aws/.
---

# Cloud Provider — AWS

## Overview

This skill covers all AWS-related Terraform modules in the cloud-provider repository, mainly around EKS clusters and their testing, autoscaling, and load-balancer scenarios.

## Modules

Repository path: `aws/`

- `eks` — EKS cluster with custom VPC.
- `eks-default-vpc` — EKS with default VPC.
- `eks-default-vpc-api` — API test scenario.
- `eks-default-vpc-dj` — DJ/middleware test scenario.
- `eks-default-vpc-multinode` — Multi-node test scenario.
- `eks-default-vpc-test` — General test scenario.
- `eks-autoscaling` — Cluster autoscaling configuration.
- `lb` — AWS load balancer resources.

## Common Workflow

After entering a specific module directory:

```bash
# Option 1: Use the module's run.sh
./run.sh -t 1 -cr us-west-2 -cn my-cluster -ns 3 -nt m6i.xlarge

# Option 2: Export required variables manually and run terraform
export TF_VAR_region='us-west-2'
terraform init -upgrade
terraform validate
terraform plan -out aws_eks
terraform apply aws_eks
```

Destroy:

```bash
./run.sh -t 2
# or
terraform destroy
```

## Common `run.sh` Parameters

- `-t 1`: initialize and create; `-t 2`: destroy.
- `-cv`: cluster version, e.g., `1.25`.
- `-cn`: cluster name.
- `-ns`: number of nodes.
- `-nt`: node instance type.
- `-cr`: AWS region.
- `-it amd64|arm64`: choose `terraform.tfvars.amd64` or `.arm64` template.
- Some modules (e.g., `eks-default-vpc-api`) also support `-ak` / `-sk` for access key, but prefer environment variables or AWS CLI profile.

## Coding Conventions

- Variables, resources, and file names use `snake_case`.
- Standard files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `run.sh`.
- In `versions.tf`, lock AWS provider (around `~> 4.x`) and Terraform version (`~> 1.3`).
- Group resource files logically, e.g., `eks.tf`, `vpc.tf`, `lb.tf`.

## Validation & Commits

- Run `terraform fmt -recursive` and `terraform validate` after changes.
- Always run `terraform plan` in a non-production environment before any `apply`.
- Use Conventional Commits such as `chore(aws): ...`, `feat(aws): ...`.
- Do not commit `.tfstate`, `.terraform/`, `terraform.tfvars`, access keys, or secret keys to Git.
