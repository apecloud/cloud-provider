variable "region" {
  # https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#availability
  description = "gke region"
  type        = string
}

variable "zone" {
  # https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#availability
  # if not set, will use the first zone in the region
  description = "gke zone"
  type        = string
}

variable "cluster_version" {
  description = "gke cluster version"
  type        = string
}

variable "cluster_name" {
  description = "gke cluster name"
  type        = string
}

variable "gke_num_nodes" {
  type        = number
  description = "number of gke nodes"
  validation {
    condition     = var.gke_num_nodes >= 1
    error_message = "gke_num_nodes must be greater than or equal to 1."
  }
}

variable "disk_size_gb" {
  type        = number
  description = "disk size gb of gke nodes"
}

variable "machine_type" {
  type        = string
  description = "machine type of gke nodes"
}

variable "spot" {
  type        = bool
  description = "spot machine"
}

variable "project" {
  type        = string
  description = "project name"
}