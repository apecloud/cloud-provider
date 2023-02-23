variable "region" {
  description = "AWS region"
  type        = string
  default     = "cn-northwest-1"
}

variable "available_zones" {
  description = "specified available zones"
  type        = list(any)
  default     = []
}

variable "access_key" {
  description = "AWS access key id"
  type        = string
  default     = ""
}

variable "access_secret" {
  description = "AWS secret access key"
  type        = string
  default     = ""
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster."
}