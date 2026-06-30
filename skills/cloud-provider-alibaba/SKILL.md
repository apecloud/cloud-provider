---
name: cloud-provider-alibaba
description: Guide maintaining Alibaba Cloud Terraform modules in the cloud-provider repository. Trigger when modifying, adding, or reviewing ACK resources, variables, ack.tf, var.tf, and versions.tf under alibaba-cloud/.
---

# Cloud Provider — Alibaba Cloud

## Overview

This skill covers Terraform configurations for Alibaba Cloud ACK (Container Service for Kubernetes) in the cloud-provider repository.

## Modules

Repository path: `alibaba-cloud/ack/`

- `ack.tf` — ACK cluster, node pool, VPC/vSwitch, RAM users, and permission policy definitions.
- `var.tf` — Cluster variables (availability zone, vSwitch CIDR, worker instance type, Terway/Flannel addon config, etc.).
- `versions.tf` / `.gitkeep` — Provider constraints and placeholder.

## Common Workflow

This module has no `run.sh`; execute directly:

```bash
cd alibaba-cloud/ack
export ALICLOUD_ACCESS_KEY=<your-access-key>
export ALICLOUD_SECRET_KEY=<your-secret-key>
export ALICLOUD_REGION=cn-hangzhou

terraform init -upgrade
terraform validate
terraform plan -out ack_plan
terraform apply ack_plan
```

Destroy:

```bash
terraform destroy
```

## Key Resources

- `alicloud_vpc`, `alicloud_vswitch` — Networking.
- `alicloud_cs_managed_kubernetes` — Managed ACK cluster, supporting Terway and Flannel network modes.
- `alicloud_cs_kubernetes_node_pool` — Default node pool.
- `alicloud_ram_policy` / `alicloud_ram_user` / `alicloud_cs_kubernetes_permissions` — Cluster access control.
- `random_uuid` — Generate cluster name suffix.

## Security & Refactoring Notes

- `ack.tf` currently hard-codes `access_key` and `secret_key` in the `provider "alicloud"` block; migrate them to environment variables or an external credential file before submitting.
- The `password` default value is only for local testing; in production, pass it via `terraform.tfvars` and manage it encrypted.
- Addon names and config in `cluster_addons_terway` / `cluster_addons_flannel` must match the ACK version; verify with official docs when modifying.

## Coding Conventions

- Variables, resources, and file names use `snake_case`.
- Maintain the standard structure of `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`; this module currently uses `ack.tf` and `var.tf`, new modules should follow standard naming.

## Validation & Commits

- `terraform fmt -recursive`
- `terraform validate` and `terraform plan`
- Commit example: `fix(alibaba): remove hard-coded alicloud credentials`
- Do not commit state, `.terraform/`, `terraform.tfvars`, or any credentials.
