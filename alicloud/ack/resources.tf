# Definition of VPC network
# For terway mode, the Pod vSwitch has same CIDR block with VPC
# For flannel mode, the Pod vSwitch has a different CIDR block with VPC
resource "alicloud_vpc" "default" {
  vpc_name   = local.vpc_name
  cidr_block = "172.16.0.0/12"
}

# vSwitch for Node network
resource "alicloud_vswitch" "vswitches" {
  count      = length(var.node_vswitch_ids) > 0 ? 0 : length(var.node_vswitch_cidrs)
  vpc_id     = alicloud_vpc.default.id
  cidr_block = element(var.node_vswitch_cidrs, count.index)
  zone_id    = element(local.available_zones, count.index)
  tags       = {
    Name = "${local.vpc_name}-node-vswitch-${count.index}"
  }
}

# According to the vswitch cidr blocks to launch several vswitches
# Check to use existing vSwitchIds declared in var or claim new ones
resource "alicloud_vswitch" "terway_vswitches" {
  count      = length(var.terway_vswitch_ids) > 0 ? 0 : length(var.terway_vswitch_cidrs)
  vpc_id     = alicloud_vpc.default.id
  cidr_block = element(var.terway_vswitch_cidrs, count.index)
  zone_id    = element(local.available_zones, count.index)
  tags       = {
    Name = "${local.vpc_name}-terway-vswitch-${count.index}"
  }
}

# set default storage class
resource "kubernetes_annotations" "default-storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"
  metadata {
    name = "alicloud-disk-topology-alltype"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
}
