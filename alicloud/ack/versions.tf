terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.19.0"
    }
    tencentcloud = {
      source  = "aliyun/alicloud"
      version = ">=1.201.2"
    }
  }
}
