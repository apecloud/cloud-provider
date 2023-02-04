variable "region" {
  description = "AWS region"
  type        = string
  default     = "cn-north-1"
}

variable "available_zones" {
  description = "available zones"
  type        = list(any)
  default     = ["cn-north-1a", "cn-north-1b"]
}
