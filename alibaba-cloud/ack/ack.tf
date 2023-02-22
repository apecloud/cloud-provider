#provider, use alicloud
provider "alicloud" {
  access_key  = ""
  secret_key  = ""
  region     = "cn-hangzhou"
}

variable "k8s_name_prefix" {
  description = "The name prefix used to create managed kubernetes cluster."
  default     = "kb-ack-hz"
}

resource "random_uuid" "this" {}

locals {
  k8s_name_terway         = substr(join("-", [var.k8s_name_prefix,"terway"]), 0, 63)
  k8s_name_flannel        = substr(join("-", [var.k8s_name_prefix,"flannel"]), 0, 63)
  k8s_name_ask            = substr(join("-", [var.k8s_name_prefix,"ask"]), 0, 63)
  new_vpc_name            = "tf-vpc-172-16"
  nodepool_name           = "default-nodepool"
  log_project_name        = "log-for-${local.k8s_name_terway}"
  policy_name             = "k8s-worker-policy"
}

# ECS vm instance for k8s Node
data "alicloud_instance_types" "default" {
  cpu_core_count       = 2
  memory_size          = 4
  availability_zone    = var.availability_zone[0]
  kubernetes_node_role = "Worker"
}

// Available zones for Node defined above
data "alicloud_zones" "default" {
  available_instance_type = data.alicloud_instance_types.default.instance_types[0].id
}

# Definition of VPC network
# For terway mode, the Pod vSwitch has same CIDR block with VPC
# For flannel mode, the Pod vSwitch has a different CIDR block with VPC
resource "alicloud_vpc" "default" {
  vpc_name   = local.new_vpc_name
  cidr_block = "172.16.0.0/12"
}

# vSwitch for Node network
resource "alicloud_vswitch" "vswitches" {
  count        = length(var.node_vswitch_ids) > 0 ? 0 : length(var.node_vswitch_cidrs)
  vpc_id       = alicloud_vpc.default.id
  cidr_block   = element(var.node_vswitch_cidrs, count.index)
  zone_id      = element(var.availability_zone, count.index)
}

# According to the vswitch cidr blocks to launch several vswitches
# Check to use existing vSwitchIds declared in var or claim new ones
resource "alicloud_vswitch" "terway_vswitches" {
  count      = length(var.terway_vswitch_ids) > 0 ? 0 : length(var.terway_vswitch_cidrs)
  vpc_id     = alicloud_vpc.default.id
  cidr_block = element(var.terway_vswitch_cidrs, count.index)
  zone_id    = element(var.availability_zone, count.index)
}

# K8s managed
resource "alicloud_cs_managed_kubernetes" "terway" {
  # K8s name
  name                      = local.k8s_name_terway

  # ack.standard is free of charge
  # ack.pro.* is in charge
  cluster_spec              = "ack.standard"
  version                   = "1.24.6-aliyun.1"

  # vSwitches for k8s nodes
  worker_vswitch_ids        = split(",", join(",", alicloud_vswitch.vswitches.*.id))

  # Nat gateway for k8s cluster
  new_nat_gateway           = true

  # Pod CIDR for flannel mode, it should be different with VPC CIDR
  # pod_cidr                  = "10.10.0.0/16"

  # vswitches for terway
  pod_vswitch_ids           = split(",", join(",", alicloud_vswitch.terway_vswitches.*.id)) 

  # CIDR for k8s service, should be different with VPC CIDR and Pod CIDR
  service_cidr              = "10.12.0.0/16"

  # SLB endpoint for API Server, default to false, if set to false, it cannot be accessed from public network
  slb_internet_enabled      = true

  # Enable Ram Role for ServiceAccount
  enable_rrsa = true

  # Log for control plane
  control_plane_log_components = ["apiserver", "kcm", "scheduler", "ccm"]

  # Addon management
  dynamic "addons" {
    for_each = var.cluster_addons_terway
    content {
      name     = lookup(addons.value, "name", var.cluster_addons_terway)
      config   = lookup(addons.value, "config", var.cluster_addons_terway)
      # disabled = lookup(addons.value, "disabled", var.cluster_addons_terway)
    }
  }

  # Runtime config, docker is deprecated
  runtime = {
    name    = "containerd"
    version = "1.5.13"
  }
}

# Node pool
resource "alicloud_cs_kubernetes_node_pool" "terway" {
  # K8s cluster name
  cluster_id            = alicloud_cs_managed_kubernetes.terway.id

  # node pool name
  name                  = local.nodepool_name

  vswitch_ids           = split(",", join(",", alicloud_vswitch.vswitches.*.id))

  # Worker ECS Type and ChargeType
  # instance_types      = [data.alicloud_instance_types.default.instance_types[0].id]
  instance_types        = var.worker_instance_types
  instance_charge_type  = "PostPaid"
  #period                = 1
  #period_unit           = "Month"
  #auto_renew            = true
  #auto_renew_period     = 1

  # customize worker instance name
  # node_name_mode      = "customized,ack-flannel-shenzhen,ip,default"

  #Container Runtime
  runtime_name          = "containerd"
  runtime_version       = "1.5.13"

  # Nodes count in k8s cluster, default 3, max 50
  desired_size          = 2
  # Password for SSH login
  password              = var.password

  # If install cloud monitor for node
  install_cloud_monitor = true

  # System disk type for node, default cloud_efficiency, alternative is cloud_ssd
  system_disk_category  = "cloud_efficiency"
  system_disk_size      = 100

  # OS Type
  image_type            = "AliyunLinux"

  # Data disk for node
  data_disks {
    # disk type
    category = "cloud_essd"
    # size in GB
    size     = 120
  }
}


# Create a new RAM Policy needed by K8S and AddOns
# Please refine me to claim necessary policies
resource "alicloud_ram_policy" "policy" {
  policy_name = local.policy_name	
  policy_document = <<EOF
  {
  "Version": "1",
  "Statement": [
    {
      "Action": [
        "ecs:DescribeInstanceAttribute",
        "ecs:DescribeInstances",
        "vpc:DescribeNatGateways"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "log:GetProject",
        "log:GetLogStore",
        "log:GetConfig",
        "log:GetMachineGroup",
        "log:GetAppliedMachineGroups",
        "log:GetAppliedConfigs",
        "log:GetIndex",
        "log:GetSavedSearch",
        "log:GetDashboard",
        "log:GetJob"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "cr:GetAuthorizationToken",
        "cr:ListInstanceEndpoint",
        "cr:PullRepository",
        "cr:GetInstanceVpcEndpoint",
        "cs:CreateCluster",
        "cs:DescribeClusterDetail",
        "cs:DescribeClusterResources",
        "cs:DescribeEvents",
        "cs:StartAlert",
        "cs:StopAlert",
        "cs:UpdateContactGroupForAlert",
        "cs:DeleteAlertContact",
        "cs:DeleteAlertContactGroup",
        "cs:DescribeUserPermission",
        "cs:OpenAckService",
        "cs:GrantPermissions",
        "cs:CreateCluster",
        "cs:DescribeClusterResources",
        "cs:DescribeClusterDetail",
        "cs:DescribeUserQuota",
        "cs:DescribeClustersV1",
        "cs:GetClusters",
        "cs:DescribeExternalAgent",
        "cs:DescribeClusterLogs",
        "cs:DescribeTaskInfo",
        "cs:DescribeKubernetesVersionMetadata",
        "cs:DescribeClusterUserKubeconfig",
        "cs:DescribeClusterAddonUpgradeStatus",
        "cs:DescribeClusters",
        "cs:GetClusters",
        "cs:DescribeClusterNamespaces",
        "cs:ScaleOutCluster",
        "cs:ModifyCluster",
        "cs:MigrateCluster",
        "cs:ScaleCluster",
        "cs:DeleteCluster",
        "cs:DescribeClusterNodes",
        "cs:AttachInstances",
        "cs:DescribeClusterAttachScripts",
        "cs:DeleteClusterNodes",
        "cs:RemoveClusterNodes",
        "cs:CreateClusterNodePool",
        "cs:DescribeClusterNodePools",
        "cs:DescribeClusterNodePoolDetail",
        "cs:ScaleClusterNodePool",
        "cs:ModifyClusterNodePool",
        "cs:DeleteClusterNodepool",
        "cs:GetUpgradeStatus",
        "cs:ResumeUpgradeCluster",
        "cs:UpgradeCluster",
        "cs:PauseClusterUpgrade",
        "cs:CancelClusterUpgrade",
        "cs:CreateTemplate",
        "cs:DescribeTemplates",
        "cs:DescribeTemplateAttribute",
        "cs:UpdateTemplate",
        "cs:DeleteTemplate",
        "cs:InstallClusterAddons",
        "cs:DescribeAddons",
        "cs:DescribeClusterAddonsUpgradeStatus",
        "cs:DescribeClusterAddonsVersion",
        "cs:ModifyClusterConfiguration",
        "cs:UpgradeClusterAddons",
        "cs:PauseComponentUpgrade",
        "cs:ResumeComponentUpgrade",
        "cs:CancelComponentUpgrade",
        "cs:UnInstallClusterAddons",
        "cs:ListTagResources",
        "cs:TagResources",
        "cs:ModifyClusterTags",
        "cs:UntagResources",
        "cs:CreateTrigger",
        "cs:DescribeTrigger",
        "cs:DeleteTrigger",
        "cs:DescribeClusterCerts"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
  }
  EOF
}

# Create a new RAM user.
resource "alicloud_ram_user" "user" {
  name         = var.user_name
  display_name = var.user_name
  comments     = "user for ACK cluster"
  force        = true
}

# Authorize the RAM user
resource "alicloud_ram_user_policy_attachment" "attach" {
  policy_name = alicloud_ram_policy.policy.name
  policy_type = alicloud_ram_policy.policy.type
  user_name   = alicloud_ram_user.user.name
}

# Grant users developer permissions for the cluster.
resource "alicloud_cs_kubernetes_permissions" "default" {
  # uid
  uid = alicloud_ram_user.user.id
  # permissions
  permissions {
    cluster     = alicloud_cs_managed_kubernetes.terway.id
    # cluster or namespace
    role_type   = "cluster"
    # admin, dev, ops, restricted
    role_name   = "admin"
    namespace   = ""
    is_custom   = false
    # when uid is a ram role, set to true
    is_ram_role = false
  }
  depends_on = [
    alicloud_ram_user_policy_attachment.attach
  ]
}
