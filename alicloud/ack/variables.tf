variable "cluster_name" {
  description = "The name of the managed kubernetes cluster."
  default     = "kb-ack-test"
}

variable "region" {
  description = "region"
  type        = string
  default     = "cn-hangzhou"
}

variable "available_zones" {
  description = "The availability zones of region."
  default     = []
}

variable "node_vswitch_ids" {
  description = "List of existing node vswitch ids for terway."
  type        = list(string)
  default     = []
}

variable "node_vswitch_cidrs" {
  description = "List of cidr blocks used to create several new vswitches when 'node_vswitch_ids' is not specified."
  type        = list(string)
  default     = ["172.16.0.0/23"]
}

variable "terway_vswitch_ids" {
  description = "List of existing pod vswitch ids for terway."
  type        = list(string)
  default     = []
}

variable "terway_vswitch_cidrs" {
  description = "List of cidr blocks used to create several new vswitches when 'terway_vswitch_ids' is not specified."
  type        = list(string)
  default     = ["172.16.208.0/20"]
}

# Node Pool worker_instance_types
variable "worker_instance_types" {
  description = "The ecs instance types used to launch worker nodes."
  default     = ["ecs.g5.xlarge", "ecs.g6.xlarge", "ecs.g7.xlarge"]
}

variable "kubernetes_version" {
  description = "The version of kubernetes."
  default     = "1.24.6-aliyun.1"
}

# Cluster Addons
variable "cluster_addons_terway" {
  type = list(object({
    name   = string
    config = string
  }))

  default = [
    {
      "name"   = "terway-eniip",
      "config" = "",
    },
    {
      "name"   = "logtail-ds",
      "config" = "{\"IngressDashboardEnabled\":\"true\"}",
    },
    {
      "name"   = "nginx-ingress-controller",
      "config" = "{\"IngressSlbNetworkType\":\"internet\"}",
    },
    {
      "name"   = "arms-prometheus",
      "config" = "",
      "disabled" : false,
    },
    {
      "name"   = "ack-node-problem-detector",
      "config" = "{\"sls_project_name\":\"\"}",
      "disabled" : false,
    },
    {
      "name"   = "csi-plugin",
      "config" = "",
    },
    {
      "name"   = "csi-provisioner",
      "config" = "",
    }
  ]
}
