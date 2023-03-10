# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "cn-northwest-1"
}

variable "additional_admin_role_names" {
  description = "Additional roles to add to the allowlist of admin accesses"
  type        = list(string)
  default     = []
}

variable "bottlerocket" {
  description = "Use Bottlerocket OS"
  type        = bool
  default     = true
}

variable "auto_scaling_group_spot_max_size" {
  description = "Max size of each EC2 auto-scaling SPOT node group"
  type        = number
  default     = 128
}

variable "auto_scaling_group_on_demand_max_size" {
  description = "Max size of each EC2 auto-scaling ON DEMAND node group"
  type        = number
  default     = 16
}

variable "default_instance_type" {
  description = "Default EC2 instance type to provision"
  type        = string
  default     = "t4g.small" # 2 vCPUs, 2GB memory
}

# t4g: cheapest
# m6g: better maximum IO and network bandwidth (30min per 24 hours)
# m6i: better maximum IO and network bandwidth (30min per 24 hours)
# See:
#   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html
#   https://www.percona.com/blog/comparing-graviton-performance-to-arm-and-intel-for-mysql/
variable "on_demand_instance_families" {
  description = "List of On-Demand EC2 instance families for Cluster Autoscaler to provision in addition to default"
  type        = list(string)
  default     = ["t4g"]
  # default     = ["t4g", "m6g", "m6i"]
}

variable "on_demand_instance_sizes" {
  description = "List of On-Demand EC2 instance sizes for Cluster Autoscaler to provision in addition to default"
  type        = list(string)
  default     = ["large", "xlarge", "2xlarge"]
}

variable "on_demand_instance_types" {
  description = "Additional On-Demand EC2 instance types for Cluster Autoscaler to provision beyond the Cartesian product of `on_demand_instance_families` and `on_demand_instance_sizes`"
  type        = list(string)
  default     = ["t4g.medium"]
}

variable "spot_instance_sizes" {
  description = "List of SPOT EC2 instance sizes for Cluster Autoscaler to provision"
  type        = list(string)
  default     = ["large", "xlarge", "2xlarge"]
}

variable "spot_arm64_instance_families" {
  description = "List of SPOT EC2 ARM64 instance families for Cluster Autoscaler to provision"
  type        = list(string)
  default     = ["t4g", "m6g"]
}

variable "spot_amd64_instance_families" {
  description = "List of SPOT EC2 AMD64 instance families for Cluster Autoscaler to provision"
  type        = list(string)
  default     = ["t3a", "t3", "m5a", "m5", "m6i"]
}

variable "karpenter_on_demand_instance_families" {
  description = "List of On-Demand EC2 instance families for Karpenter to provision"
  type        = list(string)
  default     = [ "t4g", "t3a" ]
}

variable "karpenter_spot_instance_families" {
  description = "List of SPOT EC2 instance families for Karpenter to provision"
  type        = list(string)
  default     = [ "t4g", "m6g", "t3a", "t3", "m5a", "m5", "m6i" ]
}

variable "karpenter_on_demand_instance_sizes" {
  description = "List of On-Demand EC2 instance sizes for Karpenter to provision"
  type        = list(string)
  default     = ["nano", "micro", "small", "medium", "large", "xlarge", "2xlarge"]
}

variable "karpenter_spot_instance_sizes" {
  description = "List of SPOT EC2 instance sizes for Karpenter to provision"
  type        = list(string)
  default     = ["large", "xlarge", "2xlarge"]
}

variable "karpenter_on_demand_cpu_limit" {
  description = "Maximum number of On-Demand EC2 CPUs that Karpenter can provision"
  type        = number
  default     = 256
}

variable "karpenter_spot_cpu_limit" {
  description = "Maximum number of SPOT EC2 CPUs that Karpenter can provision"
  type        = number
  default     = 256
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  description = "Time to wait to scale down a newly added node"
  type        = string
  default     = "2m" # 2 minutes
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "Time to wait to scale down a newly added node"
  type        = string
  default     = "1m" # 1 minute
}

variable "cluster_autoscaler_priorities" {
  description = "Priority assignment rules for Cluster Autoscaler"
  type        = string
  default     = <<END
95:
  - .*mng-default-.*
90:
  - .*mng-spot-auto-scaling-arm-medium.*
88:
  - .*mng-spot-auto-scaling-x64-medium.*
86:
  - .*mng-spot-auto-scaling-arm-large.*
84:
  - .*mng-spot-auto-scaling-x64-large.*
82:
  - .*mng-spot-auto-scaling-arm-xlarge.*
80:
  - .*mng-spot-auto-scaling-x64-xlarge.*
78:
  - .*mng-spot-auto-scaling-arm-2xlarge.*
76:
  - .*mng-spot-auto-scaling-x64-2xlarge.*
74:
  - .*mng-spot-auto-scaling-arm-4xlarge.*
72:
  - .*mng-spot-auto-scaling-x64-4xlarge.*
60:
  - .*mng-spot-auto-scaling-arm.*
58: 
  - .*mng-spot-auto-scaling-x64.*
50:
  - .*mng-auto-scaling-.*-medium.*
48:
  - .*mng-auto-scaling-.*-large.*
46:
  - .*mng-auto-scaling-.*-xlarge.*
44:
  - .*mng-auto-scaling-.*-2xlarge.*
42:
  - .*mng-auto-scaling-.*-8xlarge.*
10:
  - .*
END
}
