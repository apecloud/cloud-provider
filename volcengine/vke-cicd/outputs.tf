output "cluster_name" {
  value = volcengine_vke_cluster.vke-tf-cluster.name
  description = "The name of the VKE cluster."
}

#output "cluster_id" {
#  value = volcengine_vke_cluster.vke-tf-cluster.id
#  description = "The name of the VKE cluster id."
#}

#output "kubeconfig_private" {
#  value = volcengine_vke_kubeconfig.vke-tf-kubeconfig-private
#}

#output "kubeconfig_public" {
#  value = volcengine_vke_kubeconfig.vke-tf-kubeconfig-public
#}


#output "vke-cicd-test-kubeconfig" {
#  value = data.volcengine_vke_kubeconfigs.vke-tf-kubeconfigs.kubeconfigs[0].kubeconfig
#}

