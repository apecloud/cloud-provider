---
name: cloud-provider-azure
description: Guide maintaining Azure Terraform modules in the cloud-provider repository. Trigger when modifying, adding, or reviewing AKS CICD (aks-cicd, aks-cicd-test, aks-cn-cicd) resources, variables, run.sh, and versions.tf under azure/.
---

# Cloud Provider — Azure

## Overview

This skill covers Azure AKS CICD-related Terraform modules in the cloud-provider repository, including standard and China region variants.

## Modules

Repository path: `azure/`

- `aks-cicd` — AKS CICD cluster.
- `aks-cicd-test` — AKS CICD test variant.
- `aks-cn-cicd` — China region AKS CICD cluster.

## Common Workflow

```bash
cd azure/aks-cicd
./run.sh -t 1 -cr "East US" -cn my-aks -ns 3 -nt Standard_D4s_v5

# Or manual flow
export TF_VAR_region='East US'
terraform init -upgrade
terraform validate
terraform plan -out azure_aks
terraform apply azure_aks
```

Destroy:

```bash
./run.sh -t 2
# or
terraform destroy
```

## Common `run.sh` Parameters

- `-t 1|2`: create or destroy.
- `-cv`: Kubernetes version.
- `-cn`: cluster name.
- `-ns`: number of nodes (maps to `node_count`).
- `-nt`: node size (maps to `machine_type`).
- `-cr`: Azure region.
- `-ds`: OS disk size in GB.
- `-ai` / `-ap` / `-si`: Azure `appId`, `password`, `subscription_id` (prefer environment variables or CLI).
- `-it amd64|arm64`: choose `terraform.tfvars` template.

## Key Variables

`run.sh` will overwrite the following in `terraform.tfvars`:

`cluster_version`, `cluster_name`, `region`, `node_count`, `machine_type`, `disk_size_gb`, `appId`, `password`, `subscription_id`.

## Coding Conventions

- Use `snake_case`.
- Standard files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `run.sh`.
- `versions.tf` locks `hashicorp/azurerm` version, currently e.g., `4.26.0`.
- For China region modules, ensure correct Azure China endpoints and login methods.

## Validation & Commits

- `terraform fmt -recursive`
- `terraform validate` and `terraform plan`
- Commit example: `chore(azure): update aks-cicd default node size`
- Never commit `terraform.tfvars`, credentials, or state files.
