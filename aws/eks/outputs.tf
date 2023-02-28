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
