# Kubernetes provider
# https://learn.hashicorp.com/terraform/kubernetes/provision-eks-cluster#optional-configure-terraform-kubernetes-provider
# To learn how to schedule deployments and services using the provider, go here: https://learn.hashicorp.com/terraform/kubernetes/deploy-nginx-kubernetes
# The Kubernetes provider is included in this file so the EKS module can complete successfully. Otherwise, it throws an error when creating `kubernetes_config_map.aws_auth`.
# You should **not** schedule deployments and services in this workspace. This keeps workspaces modular (one for provision EKS, another for scheduling Kubernetes resources) as per best practices.

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

locals {
  cluster_name = var.cluster_name == "" ? "kb-eks-${random_string.suffix.result}" : var.cluster_name

  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = module.eks.cluster_arn
    clusters        = [
      {
        name    = module.eks.cluster_arn
        cluster = {
          certificate-authority-data = module.eks.cluster_certificate_authority_data
          server                     = module.eks.cluster_endpoint
        }
      }
    ]
    contexts = [
      {
        name    = module.eks.cluster_arn
        context = {
          cluster = module.eks.cluster_arn
          user    = module.eks.cluster_arn
        }
      }
    ]
    users = [
      {
        name = module.eks.cluster_arn
        user = {
          exec : {
            apiVersion = "client.authentication.k8s.io/v1beta1"
            command    = "aws"
            args       = [
              "eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"
            ]
          }
        }
      }
    ]
  })

  tags = {
    EKS       = local.cluster_name
    Terraform = "true"
    owner     = reverse(split("/", data.aws_caller_identity.current.arn))[0]

    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}
