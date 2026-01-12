output "kubeconfig" {
  value       = data.volcengine_vke_kubeconfigs.default.kubeconfigs[0].kubeconfig
  description = "kubeconfig for the vke cluster"
  sensitive   = true
}
