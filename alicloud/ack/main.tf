provider "alicloud" {
  region = var.region
}

provider "kubernetes" {
  host                   = alicloud_cs_managed_kubernetes.ack.connections.api_server_internet
  cluster_ca_certificate = base64decode(data.alicloud_cs_cluster_credential.auth.certificate_authority.cluster_cert)
  client_key             = base64decode(data.alicloud_cs_cluster_credential.auth.certificate_authority.client_key)
  client_certificate     = base64decode(data.alicloud_cs_cluster_credential.auth.certificate_authority.client_cert)
}

data "alicloud_cs_cluster_credential" "auth" {
  cluster_id                 = alicloud_cs_managed_kubernetes.ack.id
  temporary_duration_minutes = 4320
}

// Available zones for current region
data "alicloud_zones" "this" {
  available_instance_type     = var.worker_instance_types.1
  available_disk_category     = "cloud_efficiency"
  available_resource_creation = "VSwitch"
}

locals {
  vpc_name        = "${var.cluster_name}-vpc"
  nodepool_name   = "${var.cluster_name}-nodepool"
  ram_policy_name = "k8s-worker-policy"
  available_zones = length(var.available_zones) == 0 ? data.alicloud_zones.this.zones.*.id : var.available_zones
}
