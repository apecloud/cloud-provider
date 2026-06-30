---
name: cloud-provider-volcengine
description: Guide maintaining Volcengine Terraform modules in the cloud-provider repository. Trigger when modifying, adding, or reviewing VKE (vke-cicd, vke-cicd-cn) and resource modules (vke-resource), run.sh, and versions.tf under volcengine/.
---

# Cloud Provider — Volcengine

## Overview

This skill covers Volcengine VKE (Volcengine Kubernetes Engine) related Terraform modules in the cloud-provider repository.

## Modules

Repository path: `volcengine/`

- `vke-cicd` — VKE CICD cluster.
- `vke-cicd-cn` — China region VKE CICD cluster.
- `vke-resource` — VKE resource module.

## Common Workflow (`vke-cicd*`)

```bash
cd volcengine/vke-cicd
./run.sh -t 1 -cr cn-beijing -cn my-vke -ns 3 -nt ecs.c6i.large
```

`run.sh` will automatically select `terraform.tfvars.amd64` or `terraform.tfvars.arm64`, then run plan/apply.

Manual flow:

```bash
export TF_VAR_region='cn-beijing'
terraform init -upgrade
terraform validate
terraform plan -out volcengine_vke
terraform apply volcengine_vke

# Apply again after creating addon resources
cat > addons.tf <<'EOF'
resource "volcengine_vke_addon" "vke-tf-addon-core-dns" {
  cluster_id       = volcengine_vke_cluster.vke-tf-cluster.id
  name             = "core-dns"
  version          = "1.10.1-vke.400"
  deploy_node_type = "Node"
  deploy_mode      = "Unmanaged"
}

resource "volcengine_vke_addon" "vke-tf-addon-csi-ebs" {
  cluster_id       = volcengine_vke_cluster.vke-tf-cluster.id
  name             = "csi-ebs"
  version          = "v1.2.4"
  deploy_node_type = "Node"
  deploy_mode      = "Unmanaged"
}
EOF

terraform plan -out volcengine_vke
terraform apply volcengine_vke
```

## Destroy Workflow

For `vke-cicd*`, `run.sh` runs the following before destroy:

```bash
terraform state rm volcengine_vke_addon.vke-tf-addon-core-dns
```

Then:

```bash
terraform init
terraform destroy -auto-approve
```

## Common `run.sh` Parameters

- `-t 1|2`: create or destroy.
- `-cv`: cluster version.
- `-cn`: cluster name.
- `-ns`: number of nodes (maps to `node_count`).
- `-nt`: node size (maps to `machine_type`).
- `-cr`: Region.
- `-ds`: data disk size (maps to `volume_size`).
- `-ak` / `-sk`: Access key / Secret key (prefer environment variables).
- `-it amd64|arm64`: choose `terraform.tfvars` template.

## Coding Conventions

- Use `snake_case`.
- Standard files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `run.sh`.
- `versions.tf` locks `volcengine/volcengine` provider version (currently e.g., `0.0.150`).
- `vke-cicd*` modules follow a two-apply pattern for addons; when updating addon versions, also update the content written by `run.sh`.

## Validation & Commits

- `terraform fmt -recursive`
- `terraform validate` and `terraform plan`
- Commit example: `chore(volcengine): update vke-cicd addon versions`
- Do not commit `terraform.tfvars`, state, `.terraform/`, or credentials.
