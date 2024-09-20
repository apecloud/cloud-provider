provider "volcengine" {
  region     = local.region # 容器服务业务所在的地域。
  access_key = local.access_key # 火山引擎账号的 Access Key ID。
  secret_key = local.secret_key # 火山引擎账号的 Secret Access Key。
}

#创建 VPC
resource "volcengine_vpc" "vke-tf-vpc" {
  vpc_name    = "vke-tf-vpc-${local.name}" # 私有网络名称。
  cidr_block  = "172.16.0.0/16" # 私有网络子网网段。
}

#创建 Virtual Switch（VSW）
resource "volcengine_subnet" "vke-tf-vsw" {
  subnet_name = "vke-tf-vsw-${local.name}" # VSW 子网名称。
  cidr_block  = "172.16.0.0/24" # VSW 子网网段。
  zone_id     = "${local.zone}" # VSW 可用区。
  vpc_id      = volcengine_vpc.vke-tf-vpc.id # VSW 所属私有网络 ID。
}

#创建 VKE 集群
resource "volcengine_vke_cluster" "vke-tf-cluster" {
  name                = local.cluster_name # 集群名称。
  kubernetes_version  = local.cluster_version # 集群的 Kubernetes 版本。当前仅支持写 x.y 版本号，不支持写 x.y.z 版本号。
  # VKE 支持的 Kubernetes 版本请参见 https://www.volcengine.com/docs/6460/108841 。
  description         = "VKE cluster created by terraform for cicd test" # 集群描述。
  delete_protection_enabled = false # 集群删除保护。true：开启，false：关闭。
  cluster_config {
    subnet_ids = [volcengine_subnet.vke-tf-vsw.id] # 集群子网 ID。
    api_server_public_access_enabled = true # 开启 API Server 公网访问。true：开启，false：不开启。
    #配置 API Server 公网 EIP 计费模式及带宽
    api_server_public_access_config {
      public_access_network_config {
        billing_type    = "PostPaidByTraffic" # EIP 计费模式。PostPaidByTraffic：按量计费-按实际流量计费，PostPaidByBandwidth：按量计费-按带宽上限计费。
        bandwidth       = 10 # EIP 带宽峰值。PostPaidByTraffic 计费模式下取值范围为 1～200，PostPaidByBandwidth 计费模式下取值范围为 1～500。
      }
    }
    resource_public_access_default_enabled = true # 开启公网访问。true：开启，false：不开启。
  }

  pods_config {
    pod_network_mode = "VpcCniShared"  # 容器网络模型。VpcCniShared：VPC-CNI 网络模型，Flannel：Flannel 网络模型。
    #当网络模型为 Flannel 时 flannel_config 生效
    flannel_config {
      pod_cidrs = ["192.168.0.0/20"]  # Flannel 模型容器网络的 Pod CIDR。
      max_pods_per_node = 64  # Flannel 模型容器网络的单节点 Pod 实例数量上限。取值有 64、16、32、128、256。
    }
    #当网络模型为 VpcCniShared 时 vpc_cni_config 生效
    vpc_cni_config {
      subnet_ids = [volcengine_subnet.vke-tf-vsw.id]  # VPC-CNI 模型容器网络的 Pod 子网 ID。
    }
  }
  #配置集群 service CIDR
  services_config {
    service_cidrsv4 = ["192.168.16.0/24"]  # 集群内服务使用的 CIDR。
  }

}

resource "volcengine_vke_node_pool" "vke-tf-node-pool" {
  cluster_id = volcengine_vke_cluster.vke-tf-cluster.id
  name = "${local.node_pool_name}-${local.name}"
  node_config {
    instance_type_ids = [local.machine_type]  # 节点对应 ECS 实例的规格。
    subnet_ids = [volcengine_subnet.vke-tf-vsw.id]   # 节点网络所属的子网 ID。
    #系统盘，type 需要所选节点型号支持挂载
    system_volume {
      type = "ESSD_PL0"  # 云盘类型。ESSD_PL0：PL0 级别极速型 SSD 云盘，ESSD_FlexPL：PL1 级别极速型 SSD 云盘。
      size = 40  # 云盘容量，单位 GiB。极速型 SSD（ESSD_PL0，ESSD_FlexPL）容量取值范围 40～2048。
    }
    security {
      login {
        password = "U2VjdXJlUGEkJHcwcmQxMjM0NTY3OA=="  # 节点的访问方式，Root 用户登录密码。使用 Base64 编码格式。
      }
    }
    #设置后，第一块数据盘会mount到/mnt/vdb，并挂载/var/lib/containerd和/var/lib/kubelet目录
    #如设置了自定义挂载点，会mount到自定义挂载点，并挂载/var/lib/containerd和/var/lib/kubelet目录
    additional_container_storage_enabled = true
    #数据盘，type需要所选节点型号能挂载，支持配置自定义挂载点
    data_volumes  {
      type = "ESSD_PL0"  # 磁盘类型。ESSD_PL0：PL0 级别极速型 SSD 云盘，ESSD_FlexPL：PL1 级别极速型 SSD 云盘。
      size = local.volume_size  # 磁盘容量，单位 GiB。极速型 SSD（ESSD_PL0，ESSD_FlexPL）容量取值范围 40～2048。
    }

    ecs_tags {   #节点对应 ECS 实例绑定的标签信息，用于搜索、管理 ECS 实例。
      key = "owner"
      value = "huangzhangshu"
    }
  }
  auto_scaling {
    enabled           = true  # 是否开通节点池弹性。true：开启，false：不开启。
    max_replicas      = local.node_count + 1  # 节点池的最大节点数。
    min_replicas      = local.node_count  # 节点池的最小节点数。
    desired_replicas  = local.node_count  # 节点池的期望节点数。
    priority          = 15  # 优先级，仅对 priority 算法生效。
    subnet_policy     = "ZoneBalance"
  }
  kubernetes_config {
    #配置节点标签（label）
    labels {
      key = "owner"
      value ="huangzhangshu"
    }
    cordon = false  # 是否封锁节点。true：封锁，false：不封锁。
  }
  tags {  #节点池自定义标签
    key = "owner"
    value = "huangzhangshu"
  }
}

resource "volcengine_vke_kubeconfig" "vke-tf-kubeconfig-private" {
  cluster_id     = volcengine_vke_cluster.vke-tf-cluster.id
  type           = "Private"
  valid_duration = 24
}

resource "volcengine_vke_kubeconfig" "vke-tf-kubeconfig-public" {
  cluster_id     = volcengine_vke_cluster.vke-tf-cluster.id
  type           = "Public"
  valid_duration = 24
}
