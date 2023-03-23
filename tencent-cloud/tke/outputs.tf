output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.tke.cluster_id
}

output "region" {
  description = "region name"
  value       = var.region
}

output "kube_config" {
  description = "Kubernetes Cluster kubeconfig"
  value       = module.tke.kube_config
}

output "available_zone" {
  description = "Kubernetes Cluster available_zone"
  value       = local.available_zone
}