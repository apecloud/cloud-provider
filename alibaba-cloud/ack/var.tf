
variable "user_name" {
  description = "RAM user name for managing Kubernetes cluster"
  default     = "ackadmin"
} 

 variable "availability_zone" {
  description = "The availability zones of vswitches."
  default     = ["cn-hangzhou-g", "cn-hangzhou-h", "cn-hangzhou-i"]
}

variable "node_vswitch_ids" {
  description = "List of existing node vswitch ids for terway."
  type        = list(string)
  default     = []
}

variable "node_vswitch_cidrs" {
  description = "List of cidr blocks used to create several new vswitches when 'node_vswitch_ids' is not specified."
  type        = list(string)
  default     = ["172.16.0.0/23", "172.16.2.0/23", "172.16.4.0/23"]
}

variable "terway_vswitch_ids" {
  description = "List of existing pod vswitch ids for terway."
  type        = list(string)
  default     = []
}

variable "terway_vswitch_cidrs" {
  description = "List of cidr blocks used to create several new vswitches when 'terway_vswitch_ids' is not specified."
  type        = list(string)
  default     = ["172.16.208.0/20", "172.16.224.0/20", "172.16.240.0/20"]
}

# Node Pool worker_instance_types
variable "worker_instance_types" {
  description = "The ecs instance types used to launch worker nodes."
  default     = ["ecs.g5.xlarge", "ecs.g6.xlarge"]
}

# Password for Worker nodes
variable "password" {
  description = "The password of ECS instance."
  default     = "zijia@ACK123"
}

# Cluster Addons
variable "cluster_addons_terway" {
  type = list(object({
    name      = string
    config    = string
  }))

  default = [
    {
      "name"     = "terway-eniip",
      "config"   = "",
    },
    {
      "name"     = "logtail-ds",
      "config"   = "{\"IngressDashboardEnabled\":\"true\"}",
    },
    {
      "name"     = "nginx-ingress-controller",
      "config"   = "{\"IngressSlbNetworkType\":\"internet\"}",
    },
    {
      "name"     = "arms-prometheus",
      "config"   = "",
      "disabled": false,
    },
    {
      "name"     = "ack-node-problem-detector",
      "config"   = "{\"sls_project_name\":\"\"}",
      "disabled": false,
    },
    {
      "name"     = "csi-plugin",
      "config"   = "",
    },
    {
      "name"     = "csi-provisioner",
      "config"   = "",
    }
  ]
}



# Cluster Addons for Flannel
variable "cluster_addons_flannel" {
  type = list(object({
    name      = string
    config    = string
  }))

  default = [
    {
      "name"     = "flannel",
      "config"   = "",
    },
    {
      "name"     = "logtail-ds",
      "config"   = "{\"IngressDashboardEnabled\":\"true\"}",
    },
    {
      "name"     = "nginx-ingress-controller",
      "config"   = "{\"IngressSlbNetworkType\":\"internet\"}",
    },
    {
      "name"     = "arms-prometheus",
      "config"   = "",
      "disabled": false,
    },
    {
      "name"     = "ack-node-problem-detector",
      "config"   = "{\"sls_project_name\":\"\"}",
      "disabled": false,
    },
    {
      "name"     = "csi-plugin",
      "config"   = "",
    },
    {
      "name"     = "csi-provisioner",
      "config"   = "",
    }
  ]
}
