output "region" {
  value       = var.region
  description = "GCloud Region"
}

output "project_id" {
  value       = data.google_client_config.current.project
  description = "GCloud Project ID"
}

output "cluster_name" {
  value       = google_container_cluster.this.name
  description = "GKE Cluster Name"
}

output "kubernetes_cluster_host" {
  value       = google_container_cluster.this.endpoint
  description = "GKE Cluster Host"
}

output "kube_config" {
  value       = module.gke_auth.kubeconfig_raw
  description = "GKE Cluster kubeconfig"
  sensitive   = true
}