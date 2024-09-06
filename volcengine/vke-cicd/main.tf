# # Kubernetes provider

locals {
  access_key                = var.access_key
  secret_key                = var.secret_key
  name                      = "cicd-vke-${random_string.suffix.result}"
  cluster_name              = lower(coalesce(var.cluster_name, local.name))
  cluster_version           = var.cluster_version
  region                    = var.region
  node_pool_name            = var.node_pool_name
  machine_type              = var.machine_type
  volume_size               = var.volume_size
  node_count                = var.node_count
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}
