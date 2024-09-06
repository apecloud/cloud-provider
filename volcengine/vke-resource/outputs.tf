output "cluster_name" {
  value = volcengine_vke_cluster.vke-cicd-test.name
  description = "The name of the VKE cluster."
}
