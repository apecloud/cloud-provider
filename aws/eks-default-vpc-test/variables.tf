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
  description = "Name of the eks cluster"
  type        = string
}

variable "cluster_version" {
  description = "Version of the eks cluster"
  type        = string
}

variable "node_group_name" {
  description = "Name of the node group"
  type        = string
}

variable "cluster_role_name" {
  description = "Name of the IAM role to be created for EKS cluster"
  type        = string
  default     = ""
}

variable "node_group_role_name" {
  description = "Name of the IAM role to be created for managed node groups"
  type        = string
  default     = ""
}

variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  type        = list(string)
  default     = []
}

variable "instance_types" {
  description = "Default EC2 instance type to provision"
  type        = list(string)
}

variable "ami_type" {
  description = "Default EC2 instance to ami"
  type        = string
}

variable "capacity_type" {
  description = "Default EC2 instance type to capacity"
  type        = string
}

variable "min_size" {
  description = "Default EC2 instance min size"
  type        = number
}

variable "max_size" {
  description = "Default EC2 instance  max size"
  type        = number
}

variable "desired_size" {
  description = "Default EC2 instance  desired size"
  type        = number
}

variable "volume_size" {
  description = "Default EC2 instance volume size"
  type        = number
}