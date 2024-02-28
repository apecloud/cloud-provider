variable "appId" {
  description = "Azure Kubernetes Service Cluster service principal"
}

variable "password" {
  description = "Azure Kubernetes Service Cluster password"
}

variable "region" {
  description = "aks region"
  type        = string
}

variable "cluster_version" {
  description = "aks cluster version"
  type        = string
}

variable "cluster_name" {
  description = "aks cluster name"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "node_count" {
  type        = number
  description = "number of aks nodes"
  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be greater than or equal to 1."
  }
}

variable "disk_size_gb" {
  type        = number
  description = "disk size gb of aks nodes"
}

variable "machine_type" {
  type        = string
  description = "machine type of aks nodes"
}

