provider "tencentcloud" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.tke.cluster_endpoint
  cluster_ca_certificate = module.tke.cluster_ca_certificate
  client_key             = base64decode(module.tke.client_key)
  client_certificate     = base64decode(module.tke.client_certificate)
}

data "tencentcloud_availability_zones_by_product" "cvm" {
  product = "cvm"
}

locals {
  available_zone = data.tencentcloud_availability_zones_by_product.cvm.zones.0.name
}