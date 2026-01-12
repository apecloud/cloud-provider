provider "volcengine" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

# query available zones in current region
data "volcengine_zones" "default" {
}

# create vpc
resource "volcengine_vpc" "default" {
  vpc_name   = "${var.cluster_name}-vpc"
  cidr_block = "172.16.0.0/16"
  tags {
    key   = "owner"
    value = var.owner
  }
}

# create subnet
resource "volcengine_subnet" "default" {
  subnet_name = "${var.cluster_name}-subnet"
  cidr_block  = "172.16.0.0/24"
  zone_id     = data.volcengine_zones.default.zones[0].id
  vpc_id      = volcengine_vpc.default.id
}

# create security group
resource "volcengine_security_group" "default" {
  security_group_name = "${var.cluster_name}-security-group"
  vpc_id              = volcengine_vpc.default.id
}

# create vke cluster
resource "volcengine_vke_cluster" "default" {
  name                      = var.cluster_name
  description               = "created by terraform"
  project_name              = "default"
  delete_protection_enabled = false
  irsa_enabled              = false
  cluster_config {
    subnet_ids                       = [volcengine_subnet.default.id]
    api_server_public_access_enabled = true
    api_server_public_access_config {
      public_access_network_config {
        billing_type = "PostPaidByBandwidth"
        bandwidth    = 1
      }
    }
    resource_public_access_default_enabled = true
  }
  pods_config {
    pod_network_mode = "VpcCniShared"
    vpc_cni_config {
      subnet_ids = [volcengine_subnet.default.id]
    }
  }
  services_config {
    service_cidrsv4 = ["172.30.0.0/18"]
  }
  # logging_config {
  #   log_setups {
  #     log_type = "KubeApiServer"
  #     enabled  = true
  #     log_ttl  = 60
  #   }
  #   log_setups {
  #     log_type = "Etcd"
  #     enabled  = false
  #     log_ttl  = 60
  #   }
  # }
  tags {
    key   = "owner"
    value = var.owner
  }
}

# query the image_id which match the specified image_name
data "volcengine_images" "default" {
  name_regex = "veLinux 1.0 CentOS Compatible 64 bit"
}

# create vke node pool
resource "volcengine_vke_node_pool" "default" {
  cluster_id = volcengine_vke_cluster.default.id
  name       = "${var.cluster_name}-node-pool"
  management {
    enabled = false
  }
  auto_scaling {
    enabled          = true
    min_replicas     = 0
    max_replicas     = 5
    desired_replicas = 3
  }
  node_config {
    instance_type_ids = ["ecs.g4il.2xlarge"]
    subnet_ids        = [volcengine_subnet.default.id]
    image_id          = [for image in data.volcengine_images.default.images : image.image_id if image.image_name == "veLinux 1.0 CentOS Compatible 64 bit"][0]
    system_volume {
      type = "ESSD_PL0"
      size = 200
    }
    # data_volumes {
    #   type        = "ESSD_PL0"
    #   size        = 200
    #   mount_point = "/tf1"
    # }
    security {
      login {
        password = base64encode(var.node_root_password)
      }
      security_group_ids = [volcengine_security_group.default.id]
    }
    additional_container_storage_enabled = false
    instance_charge_type                 = "PostPaid"
    name_prefix                          = var.cluster_name
    project_name                         = "default"
    ecs_tags {
      key   = "owner"
      value = var.owner
    }
  }
  kubernetes_config {
    cordon = false
  }
  tags {
    key   = "owner"
    value = var.owner
  }
}

resource "volcengine_vke_addon" "coredns" {
  cluster_id = volcengine_vke_cluster.default.id
  name       = "core-dns"
  # below is default config
  # config = jsonencode(
  #   {
  #     Resources = {
  #       Limits = {
  #         Memory = "4Gi"
  #       }
  #       Requests = {
  #         Cpu    = "2"
  #         Memory = "4Gi"
  #       }
  #     }
  #   }
  # )
}

resource "volcengine_vke_addon" "csi-ebs" {
  cluster_id = volcengine_vke_cluster.default.id
  name       = "csi-ebs"
  # below is default config
  # config = jsonencode(
  #   {
  #     CsiAttacher = {
  #       Resources = {
  #         Limits = {
  #           Cpu    = "0.3"
  #           Memory = "900Mi"
  #         }
  #         Requests = {
  #           Cpu    = "0.01"
  #           Memory = "20Mi"
  #         }
  #       }
  #     }
  #     CsiEbsDriver = {
  #       Resources = {
  #         Limits = {
  #           Cpu    = "0.7"
  #           Memory = "1Gi"
  #         }
  #         Requests = {
  #           Cpu    = "0.01"
  #           Memory = "20Mi"
  #         }
  #       }
  #     }
  #     CsiProvisioner = {
  #       Resources = {
  #         Limits = {
  #           Cpu    = "0.3"
  #           Memory = "900Mi"
  #         }
  #         Requests = {
  #           Cpu    = "0.01"
  #           Memory = "20Mi"
  #         }
  #       }
  #     }
  #     CsiResizer = {
  #       Resources = {
  #         Limits = {
  #           Cpu    = "0.3"
  #           Memory = "800Mi"
  #         }
  #         Requests = {
  #           Cpu    = "0.01"
  #           Memory = "20Mi"
  #         }
  #       }
  #     }
  #     CsiSnapshotter = {
  #       Resources = {
  #         Limits = {
  #           Cpu    = "0.3"
  #           Memory = "300Mi"
  #         }
  #         Requests = {
  #           Cpu    = "0.01"
  #           Memory = "20Mi"
  #         }
  #       }
  #     }
  #     EnableWaitAPIServerClusterIPReady = false
  #     LivenessProbe = {
  #       Resources = {
  #         Limits = {
  #           Cpu    = "0.1"
  #           Memory = "100Mi"
  #         }
  #         Requests = {
  #           Cpu    = "0.01"
  #           Memory = "20Mi"
  #         }
  #       }
  #     }
  #     NodeAllocatedVolumesMetricEnabled = false
  #     NodeHealthPort                    = 9808
  #     NodeMetricsEndpointPort           = 11815
  #   }
  # )
}

resource "volcengine_vke_kubeconfig" "default" {
  cluster_id     = volcengine_vke_cluster.default.id
  type           = "Public"
  valid_duration = 43800 # 5 years
}

data "volcengine_vke_kubeconfigs" "default" {
  ids = [volcengine_vke_kubeconfig.default.id]
}

locals {
  kubeconfig = yamldecode(base64decode(data.volcengine_vke_kubeconfigs.default.kubeconfigs[0].kubeconfig))
}

provider "kubernetes" {
  host = local.kubeconfig.clusters[0].cluster.server

  client_certificate     = base64decode(local.kubeconfig.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kubeconfig.users[0].user.client-key-data)
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
}

resource "kubernetes_annotations" "csi-ebs" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "ebs-ssd"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
}
