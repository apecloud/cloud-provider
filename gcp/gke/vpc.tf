
variable "region" {
  # https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#availability
  description = "region"
  default     = "us-central1"
}

variable "zone" {
  # https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#availability
  description = "zone"
  default     = "us-central1-f"
}

provider "google" {
  project = var.project_id
  credentials = var.gcp_credentials
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}
