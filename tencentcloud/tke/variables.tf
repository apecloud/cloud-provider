variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
  default     = "kb-tke-test"
}

variable "region" {
  description = "region"
  type        = string
  default     = "ap-chengdu"
}
