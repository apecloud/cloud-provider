variable "region" {
  # https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#availability
  description = "region"
  default     = "us-central1"
}

variable "zone" {
  # https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#availability
  # if not set, will use the first zone in the region
  description = "zone"
  default     = ""
}

variable "cluster_name" {
  description = "gke cluster name"
  default     = "kb-gke-test"
}

variable "gke_num_nodes" {
  default     = 3
  description = "number of gke nodes"
  validation {
    condition     = var.gke_num_nodes >= 1
    error_message = "gke_num_nodes must be greater than or equal to 1."
  }
}