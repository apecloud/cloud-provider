# refer https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/cs_managed_kubernetes

# K8s managed
resource "alicloud_cs_managed_kubernetes" "ack" {
  name = var.cluster_name

  # ack.standard is free of charge
  # ack.pro.* is in charge, such as ack.pro.small
  cluster_spec = "ack.standard"
  version      = var.kubernetes_version

  # vSwitches for k8s nodes
  worker_vswitch_ids = split(",", join(",", alicloud_vswitch.vswitches.*.id))

  # Nat gateway for k8s cluster
  # NOTE: NatGateway may be not supported in all selected zones
  new_nat_gateway = true

  # Pod CIDR for flannel mode, it should be different with VPC CIDR
  # pod_cidr                  = "10.10.0.0/16"

  # vswitches for terway
  pod_vswitch_ids = split(",", join(",", alicloud_vswitch.terway_vswitches.*.id))

  # CIDR for k8s service, should be different with VPC CIDR and Pod CIDR
  service_cidr = "10.12.0.0/16"

  # SLB endpoint for API Server, default to false, if set to false, it cannot be accessed from public network
  slb_internet_enabled = true

  # Enable Ram Role for ServiceAccount
  enable_rrsa = false

  # Log for control plane
  control_plane_log_components = ["apiserver", "kcm", "scheduler", "ccm"]

  # Addon management
  dynamic "addons" {
    for_each = var.cluster_addons_terway
    content {
      name   = lookup(addons.value, "name", var.cluster_addons_terway)
      config = lookup(addons.value, "config", var.cluster_addons_terway)
    }
  }
}

# Node pool
resource "alicloud_cs_kubernetes_node_pool" "this" {
  # K8s cluster name
  cluster_id = alicloud_cs_managed_kubernetes.ack.id

  # node pool name
  name = local.nodepool_name

  vswitch_ids = split(",", join(",", alicloud_vswitch.vswitches.*.id))

  # Worker ECS Type and ChargeType
  instance_types       = var.worker_instance_types
  instance_charge_type = "PostPaid"
  #period                = 1
  #period_unit           = "Month"
  #auto_renew            = true
  #auto_renew_period     = 1

  # customize worker instance name
  # node_name_mode      = "customized,ack-flannel-shenzhen,ip,default"

  #Container Runtime
  runtime_name    = "containerd"
  runtime_version = "1.5.13"

  # Nodes count in k8s cluster, default 3, max 50
  desired_size = 3
  # Password for SSH login
  password     = random_password.worker_pwd.result

  # If install cloud monitor for node
  install_cloud_monitor = false

  # System disk type for node, default cloud_efficiency, alternative is cloud_ssd or cloud_essd
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 40

  # OS Type
  image_type = "AliyunLinux"
}

resource "random_password" "worker_pwd" {
  length           = 12
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
