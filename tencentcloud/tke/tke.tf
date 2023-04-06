resource "tencentcloud_kubernetes_cluster" "this" {
  vpc_id                  = tencentcloud_vpc.this.id
  cluster_cidr            = "10.31.0.0/16"
  cluster_max_pod_num     = 32
  cluster_name            = var.cluster_name
  cluster_desc            = "TKE created by KubeBlocks"
  cluster_max_service_num = 32
  cluster_internet        = true
  cluster_deploy_type     = "MANAGED_CLUSTER"
  cluster_os              = "centos7.8.0_x64"
  cluster_version         = "1.24.4"
  container_runtime       = "containerd"
  runtime_version         = "1.6.9"

  cluster_internet_security_group = tencentcloud_security_group.this.id

  worker_config {
    count             = 3
    availability_zone = local.available_zone

    # https://cloud.tencent.com/document/product/213/11518
    instance_type              = "S5.MEDIUM8"  #2c8g
    system_disk_type           = "CLOUD_SSD"
    system_disk_size           = 50
    internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
    internet_max_bandwidth_out = 100
    public_ip_assigned         = true
    subnet_id                  = tencentcloud_subnet.this.id
    password                   = random_password.worker_pwd.result

    data_disk {
      disk_type = "CLOUD_PREMIUM"
      disk_size = 50
    }

    enhanced_security_service = false
    enhanced_monitor_service  = false
  }

  cluster_audit {
    enabled = false
  }

  event_persistence {
    enabled = false
  }

  tags = {
    "app" = "kubeblocks",
  }

  labels = {
    "app" = "kubeblocks",
  }

  extra_args = [
    "root-dir=/var/lib/kubelet"
  ]

  depends_on = [
    tencentcloud_vpc.this,
    tencentcloud_subnet.this,
    tencentcloud_security_group.this,
    tencentcloud_security_group_lite_rule.this,
  ]
}

resource "random_password" "worker_pwd" {
  length           = 12
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
