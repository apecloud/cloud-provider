terraform {
  required_providers {
    volcengine = {
      source  = "volcengine/volcengine"
      version = "0.0.182"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}
