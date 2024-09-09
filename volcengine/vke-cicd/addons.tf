resource "volcengine_vke_addon" "vke-tf-addon-core-dns" {
  cluster_id       = volcengine_vke_cluster.vke-tf-cluster.id
  name             = "core-dns"
  version          = "1.10.1-vke.400"
  deploy_node_type = "Node"
  deploy_mode      = "Unmanaged"
}

resource "volcengine_vke_addon" "vke-tf-addon-csi-ebs" {
  cluster_id       = volcengine_vke_cluster.vke-tf-cluster.id
  name             = "csi-ebs"
  version          = "v1.2.4"
  deploy_node_type = "Node"
  deploy_mode      = "Unmanaged"
}
