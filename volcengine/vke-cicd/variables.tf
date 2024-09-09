variable "access_key" {
  description = "Volcengine access key"
}

variable "secret_key" {
  description = "Volcengine secret key"
}

variable "region" {
  description = "vke region"
  type        = string
}

variable "region_zone" {
  description = "vke region zone"
  type        = string
}

variable "cluster_version" {
  description = "vke cluster version"
  type        = string
}

variable "cluster_name" {
  description = "vke cluster name"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "node_count" {
  type        = number
  description = "number of vke nodes"
  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be greater than or equal to 1."
  }
}

variable "volume_size" {
  type        = number
  description = "size of volume"
}

variable "machine_type" {
  type        = string
  description = "machine type of vke nodes"
}

