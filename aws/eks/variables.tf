variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster."
  default     = "kb-eks-test"
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
  default     = "t3a.large" # 2 vCPUs, 8GB memory
}

variable "arch" {
  description = "The architecture of the AMI to use"
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "The architecture must be amd64 or arm64."
  }
}

variable "capacity_type" {
  description = "The capacity type of the node group"
  type        = string
  default     = "SPOT"    # ON_DEMAND or SPOT
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "The capacity type must be ON_DEMAND or SPOT."
  }
}