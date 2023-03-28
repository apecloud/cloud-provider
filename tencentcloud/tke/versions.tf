terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.19.0"
    }
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = ">=1.79.18"
    }
  }
}
