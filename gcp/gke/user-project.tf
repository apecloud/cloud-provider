variable "gke_username" {
  default     = "kbadmin"
  description = "gke username"
}

variable "gke_password" {
  default     = "123@kb"
  description = "gke password"
}

variable "project_id" {
  description = "project name"
  default     = "firstgke-378617"
}

variable "gcp_credentials" {
  type = string
  sensitive = true
  description = "Google Cloud service account credentials"
}
