output "cluster_name" {
  description = "Kubernetes Cluster name"
  value       = var.cluster_name
}

output "region" {
  description = "region name"
  value       = var.region
}

output "kube_config" {
  description = "Kubernetes Cluster kubeconfig"
  value       = tencentcloud_kubernetes_cluster.this.kube_config
  sensitive   = true
}

output "available_zone" {
  description = "Kubernetes Cluster available_zone"
  value       = local.available_zone
}