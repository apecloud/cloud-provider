# # Google provider
# # we only need to specify the region here, other variables are read from the environment
provider "google" {
  region = var.region
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

data "google_compute_zones" "zones" {}

locals {
  project_id = data.google_client_config.current.project
  zone       = var.zone == "" ? data.google_compute_zones.zones.names[0] : var.zone
}