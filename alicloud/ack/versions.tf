terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.18.1"
    }
    tencentcloud = {
      source  = "aliyun/alicloud"
      version = ">=1.201.2"
    }
  }
}
