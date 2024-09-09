output "cluster_name" {
  value = volcengine_vke_cluster.vke-tf-cluster.name
  description = "The name of the VKE cluster."
}

#output "cluster_id" {
#  value = volcengine_vke_cluster.vke-tf-cluster.id
#  description = "The name of the VKE cluster id."
#}