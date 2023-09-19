output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_addons" {
  description = "EKS addons"
  value       = module.eks.cluster_addons
}

output "vpc_available_zones" {
  description = "VPC available zones"
  value       = module.vpc.azs
}

output "cluster_arn" {
  description = "The Cluster Name (ARN)"
  value       = module.eks.cluster_arn
}

output "kube_config" {
  description = "Kubeconfig"
  value       = yamlencode({
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
  sensitive   = true
}