---
name: cloud-provider-tencent
description: Guide maintaining Tencent Cloud Terraform modules in the cloud-provider repository. Trigger when modifying, adding, or reviewing TKE resources, variables, main.tf, clb.tf, and resources.tf under tencent-cloud/.
---

# Cloud Provider — Tencent Cloud

## Overview

This skill covers Tencent Cloud TKE (Tencent Kubernetes Engine) example modules in the cloud-provider repository, including VPC, subnets, security groups, CLB, and Kubernetes applications based on the TKE module.

## Modules

Repository path: `tencent-cloud/tke/`

- `main.tf` — Provider, network, security group, TKE module call, and kubernetes provider configuration.
- `clb.tf` — CLB instances.
- `resources.tf` — Kubernetes namespace, deployment, service, and ingress examples.
- `variables.tf` / `outputs.tf` — Variables and outputs.
- `README.md` — Usage instructions.

## Common Workflow

This module has no `run.sh`:

```bash
cd tencent-cloud/tke
export TENCENTCLOUD_SECRET_ID=<secret-id>
export TENCENTCLOUD_SECRET_KEY=<secret-key>
export TENCENTCLOUD_REGION=ap-guangzhou

terraform init -upgrade
terraform validate
terraform plan
terraform apply
```

Destroy:

```bash
terraform destroy
```

## Key Resources

- `tencentcloud_vpc`, `tencentcloud_subnet` — Basic networking.
- `tencentcloud_security_group` / `tencentcloud_security_group_lite_rule` — Security group rules.
- `module.tencentcloud_tke` (source `../../`) — TKE cluster module.
- `tencentcloud_clb_instance` — Application load balancer.
- `kubernetes_namespace`, `kubernetes_deployment`, `kubernetes_service`, `kubernetes_ingress_v1` — Example applications.

## Notes

- `module.tencentcloud_tke` uses relative path `../../`; ensure repository structure stays consistent when modifying the path.
- Ingress annotations (`ingress.cloud.tencent.com/*`, `kubernetes.io/ingress.qcloud-loadbalance-id`, etc.) are Tencent Cloud CLB-specific; refer to TKE official docs when adjusting.
- In `security_group_lite_rule`, the default `accept_ip` is a test IP; pass it via variable in production.

## Coding Conventions

- Use `snake_case`.
- Standard files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- Provider constraints: `tencentcloudstack/tencentcloud >= 1.79.2`, `hashicorp/kubernetes >= 2.0.0`.

## Validation & Commits

- `terraform fmt -recursive`
- `terraform validate` and `terraform plan`
- Commit example: `chore(tencent): update tke available zone default`
- Do not commit credentials or state files.
