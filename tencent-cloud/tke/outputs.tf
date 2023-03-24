output "cluster_name" {
  description = "Kubernetes Cluster ID, this cluster name is used to kubeconfig"
  value       = tencentcloud_kubernetes_cluster.this.id
}

output "region" {
  description = "region name"
  value       = var.region
}

output "kube_config" {
  description = "Kubernetes Cluster kubeconfig"
  value       = tencentcloud_kubernetes_cluster.this.kube_config
}

output "available_zone" {
  description = "Kubernetes Cluster available_zone"
  value       = local.available_zone
}