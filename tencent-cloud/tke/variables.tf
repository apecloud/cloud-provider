variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
  default     = "tke-test"
}

variable "region" {
  description = "region"
  type        = string
  default     = "ap-chengdu"
}
