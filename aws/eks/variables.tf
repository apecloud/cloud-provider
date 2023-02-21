variable "region" {
  description = "AWS region"
  type        = string
  default     = ""
}

variable "available_zones" {
  description = "specified available zones"
  type        = list(any)
  default     = []
}

