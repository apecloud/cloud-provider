module "tke" {
  source             = "terraform-tencentcloud-modules/tke/tencentcloud"
  version            = "0.2.0"
  available_zone     = local.available_zone
  vpc_id             = tencentcloud_vpc.this.id
  intranet_subnet_id = tencentcloud_subnet.intranet.id
  cluster_os         = "centos7.8.0_x64"
  cluster_name       = var.cluster_name
  cluster_version    = "1.24.4"

  enable_event_persistence = false
  enable_cluster_audit_log = false
  enhanced_monitor_service = false
  cluster_public_access    = true
  cluster_private_access   = true

  cluster_security_group_id        = tencentcloud_security_group.this.id
  node_security_group_id           = tencentcloud_security_group.this.id
  cluster_private_access_subnet_id = tencentcloud_subnet.intranet.id

  worker_bandwidth_out = 100
  worker_count         = 3

  tags = {
    app = "kubeblocks"
  }

  self_managed_node_groups = {
    kb-ng = {
      max_size                 = 6
      min_size                 = 1
      subnet_ids               = [tencentcloud_subnet.intranet.id]
      retry_policy             = "INCREMENTAL_INTERVALS"
      desired_capacity         = 3
      enable_auto_scale        = false
      multi_zone_subnet_policy = "EQUALITY"
      security_group_ids       = [tencentcloud_security_group.this.id]
      auto_scaling_config      = [
        {
          # https://cloud.tencent.com/document/product/213/11518
          instance_type      = "S5.MEDIUM8"  #2c8g
          system_disk_type   = "CLOUD_PREMIUM"
          system_disk_size   = 50
          security_group_ids = [tencentcloud_security_group.this.id]
          data_disk          = [
            {
              disk_type = "CLOUD_PREMIUM"
              disk_size = 50
            }
          ]
          internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
          internet_max_bandwidth_out = 10
          public_ip_assigned         = true
          enhanced_security_service  = false
          enhanced_monitor_service   = false
          host_name                  = "12.123.0.0"
          host_name_style            = "ORIGINAL"
        }
      ]

      labels = {
        "tke" = var.cluster_name,
      }

      taints = [
        {
          key    = "test_taint"
          value  = "taint_value"
          effect = "PreferNoSchedule"
        },
        {
          key    = "test_taint2"
          value  = "taint_value2"
          effect = "PreferNoSchedule"
        }
      ]

      node_config = [
        {
          extra_args = ["root-dir=/var/lib/kubelet"]
        }
      ]
    }
  }
}
