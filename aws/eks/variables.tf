variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster."
  default     = ""
}

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

variable "instance_type" {
  description = "Default EC2 instance type to provision"
  type        = string
  default     = "t3.large" # 2 vCPUs, 8GB memory
}

variable "arch" {
  description = "The architecture of the AMI to use"
  type        = string
  default     = "x86"    # x86 or arm
  validation {
    condition     = contains(["x86", "arm"], var.arch)
    error_message = "The architecture must be x86 or arm."
  }
}

variable "capacity_type" {
  description = "The capacity type of the node group"
  type        = string
  default     = "ON_DEMAND"    # ON_DEMAND or SPOT
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "The capacity type must be ON_DEMAND or SPOT."
  }
}