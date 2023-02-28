variable "region" {
  description = "AWS region"
  type        = string
}

variable "available_zones" {
  description = "specified available zones"
  type        = list(any)
  default     = []
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster."
}