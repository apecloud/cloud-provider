variable "access_key" {
  description = "Volcengine Access Key"
  type        = string
}

variable "secret_key" {
  description = "Volcengine Secret Key"
  type        = string
}

variable "region" {
  description = "region"
  type        = string
  default     = "cn-guangzhou"
}

variable "cluster_name" {
  description = "name of vke cluster, also will be used as the prefix of other resources"
  type        = string
}

variable "owner" {
  description = "owner of the resource"
  type        = string
}

variable "node_root_password" {
  description = "password of root account in every node"
  type        = string
}
