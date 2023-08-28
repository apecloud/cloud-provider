# # Google provider
# # we only need to specify the region here, other variables are read from the environment
provider "google" {
  region = local.region
  project = local.project
}

# # Kubernetes provider
provider "kubernetes" {
  cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
  host                   = module.gke_auth.host
  token                  = module.gke_auth.token
}

# # https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/auth
module "gke_auth" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version      = "25.0.0"
  depends_on   = [google_container_cluster.this]
  project_id   = local.project_id
  location     = google_container_cluster.this.location
  cluster_name = google_container_cluster.this.name
}

# # Get the project ID from Google ADC
data "google_client_config" "current" {}


locals {
  project_id = data.google_client_config.current.project
  project                   = var.project
  name                      = "cicd-gke-${random_string.suffix.result}"
  cluster_name              = lower(coalesce(var.cluster_name, local.name))
  cluster_version           = var.cluster_version
  region                    = var.region
  zone                      = var.zone
  gke_num_nodes             = var.gke_num_nodes
  disk_size_gb              = var.disk_size_gb
  machine_type              = var.machine_type
  spot                      = var.spot
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}