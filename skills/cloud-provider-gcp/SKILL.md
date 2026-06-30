---
name: cloud-provider-gcp
description: Guide maintaining GCP Terraform modules in the cloud-provider repository. Trigger when modifying, adding, or reviewing GKE (gke, gke-cicd) resources, variables, run.sh, and versions.tf under gcp/.
---

# Cloud Provider — GCP

## Overview

This skill covers Google Cloud GKE-related Terraform modules in the cloud-provider repository.

## Modules

Repository path: `gcp/`

- `gke` — Standard GKE cluster module.
- `gke-cicd` — GKE CICD cluster module.

## Common Workflow

```bash
cd gcp/gke-cicd
./run.sh -t 1 -cr us-central1 -cn my-gke -ns 3 -nt e2-standard-4

# Or manual flow
export TF_VAR_region='us-central1'
terraform init -upgrade
terraform validate
terraform plan -out gcp_gke
terraform apply gcp_gke
```

Destroy:

```bash
./run.sh -t 2
# or
terraform destroy
```

## Common `run.sh` Parameters

- `-t 1|2`: create or destroy.
- `-cv`: GKE version.
- `-cn`: cluster name.
- `-ns`: number of nodes (maps to `gke_num_nodes`).
- `-nt`: machine type (maps to `machine_type`).
- `-cr`: GCP region (also overwrites `zone`).
- `-es true|false`: whether to enable spot instances (default `true`).
- `-ds`: disk size in GB.
- `-it amd64|arm64`: choose `terraform.tfvars` template.

## Key Variables

`run.sh` will overwrite the following in `terraform.tfvars`:

`cluster_version`, `cluster_name`, `region`, `zone`, `gke_num_nodes`, `machine_type`, `spot`, `disk_size_gb`.

## Coding Conventions

- Use `snake_case`.
- Standard files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `run.sh`.
- `versions.tf` locks `hashicorp/google` and `hashicorp/kubernetes` provider versions.

## Validation & Commits

- `terraform fmt -recursive`
- `terraform validate` and `terraform plan`
- Commit example: `chore(gcp): bump gke-cicd provider version`
- Do not hard-code GCP Service Account keys in code; use ADC, `GOOGLE_APPLICATION_CREDENTIALS`, or gcloud auth.
