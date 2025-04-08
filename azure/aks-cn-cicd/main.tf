# # Kubernetes provider

locals {
  appId                     = var.appId
  password                  = var.password
  subscription_id           = var.subscription_id
  name                      = "cicd-aks-${random_string.suffix.result}"
  cluster_name              = lower(coalesce(var.cluster_name, local.name))
  cluster_version           = var.cluster_version
  region                    = var.region
  node_pool_name            = var.node_pool_name
  machine_type              = var.machine_type
  disk_size_gb              = var.disk_size_gb
  node_count                = var.node_count
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}
