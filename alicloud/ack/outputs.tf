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
  value       = data.alicloud_cs_cluster_credential.auth.kube_config
  sensitive   = true
}

output "available_zone" {
  description = "Kubernetes Cluster available_zone"
  value       = alicloud_cs_managed_kubernetes.ack.availability_zone
}

output "node_password" {
  description = "Kubernetes Cluster node password"
  value       = alicloud_cs_kubernetes_node_pool.this.password
  sensitive   = true
}