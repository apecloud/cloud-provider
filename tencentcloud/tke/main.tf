provider "tencentcloud" {
  region = var.region
}

provider "kubernetes" {
  host                   = tencentcloud_kubernetes_cluster.this.cluster_external_endpoint
  cluster_ca_certificate = tencentcloud_kubernetes_cluster.this.certification_authority
  client_key             = base64decode(local.kube_config.users[0].user["client-key-data"])
  client_certificate     = base64decode(local.kube_config.users[0].user["client-certificate-data"])
}

data "tencentcloud_availability_zones_by_product" "cvm" {
  product = "cvm"
}

locals {
  available_zone = data.tencentcloud_availability_zones_by_product.cvm.zones.0.name
  kube_config    = yamldecode(tencentcloud_kubernetes_cluster.this.kube_config)
}