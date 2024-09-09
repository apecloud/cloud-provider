provider "volcengine" {
  region     = local.region
  access_key = local.access_key
  secret_key = local.secret_key
}

resource "volcengine_vpc" "vke-tf-vpc" {
  vpc_name    = "vke-tf-vpc-${local.name}"
  cidr_block  = "172.16.0.0/16"
}

resource "volcengine_subnet" "vke-tf-vsw" {
  subnet_name = "vke-tf-vsw-${local.name}"
  cidr_block  = "172.16.0.0/24"
  zone_id     = "${local.region_zone}"
  vpc_id      = volcengine_vpc.vke-tf-vpc.id
}

resource "volcengine_security_group" "vke-tf-security-group" {
  security_group_name = "vke-tf-security-group-${local.name}"
  vpc_id              = volcengine_vpc.vke-tf-vpc.id
}

data "volcengine_images" "vke-tf-images" {
  name_regex = "veLinux 1.0 CentOS Compatible 64 bit"
}

resource "volcengine_vke_cluster" "vke-tf-cluster" {
  name                = local.cluster_name
  kubernetes_version  = local.cluster_version
  description         = "VKE cluster created by terraform"
  delete_protection_enabled = false
  cluster_config {
    subnet_ids = [volcengine_subnet.vke-tf-vsw.id]
    api_server_public_access_enabled = true
    api_server_public_access_config {
      public_access_network_config {
        billing_type    = "PostPaidByTraffic"
        bandwidth       = 10
      }
    }
    resource_public_access_default_enabled = true
  }

  pods_config {
    pod_network_mode = "VpcCniShared"
    flannel_config {
      pod_cidrs = ["192.168.0.0/20"]
      max_pods_per_node = 64
    }
    vpc_cni_config {
      subnet_ids = [volcengine_subnet.vke-tf-vsw.id]
    }
  }
  services_config {
    service_cidrsv4 = ["172.30.0.0/18"]
  }
  tags {
    key   = "owner"
    value = "huangzhangshu"
  }
}

resource "volcengine_vke_node_pool" "vke-tf-node-pool" {
  cluster_id = volcengine_vke_cluster.vke-tf-cluster.id
  name = "${local.node_pool_name}-${local.name}"
  auto_scaling {
    enabled = false
  }
  node_config {
    instance_type_ids = [local.machine_type]
    subnet_ids = [volcengine_subnet.vke-tf-vsw.id]
    image_id          = [for image in data.volcengine_images.vke-tf-images.images : image.image_id if image.image_name == "veLinux 1.0 CentOS Compatible 64 bit"][0]
    system_volume {
      type = "ESSD_PL0"
      size = 50
    }
    data_volumes  {
      type = "ESSD_PL0"
      size = local.volume_size
      mount_point = "/tf"
    }
    initialize_script = "ZWNobyBoZWxsbyB0ZXJyYWZvcm0h"
    security {
      login {
        password = "U2VjdXJlUGEkJHcwcmQxMjM0NTY3OA=="
      }
      security_strategies = ["Hids"]
      security_group_ids  = [volcengine_security_group.vke-tf-security-group.id]
    }
    additional_container_storage_enabled = true
    instance_charge_type                 = "PostPaid"
    name_prefix       = "vke-tf-${local.name}"
    ecs_tags {
      key = "owner"
      value = "huangzhangshu"
    }
  }

  kubernetes_config {
    labels {
      key = "owner"
      value ="huangzhangshu"
    }
    cordon = false
  }
  tags {
    key = "owner"
    value = "huangzhangshu"
  }
}

resource "volcengine_ecs_instance" "vke-tf-ecs-instance" {
  instance_name        = "vke-tf-ecs-instance-${local.name}-${count.index}"
  host_name            = "vke-tf-ecs-instance-${local.name}"
  image_id             = [for image in data.volcengine_images.vke-tf-images.images : image.image_id if image.image_name == "veLinux 1.0 CentOS Compatible 64 bit"][0]
  instance_type        = local.machine_type
  password             = "93f0cb0614Aab12"
  instance_charge_type = "PostPaid"
  system_volume_type   = "ESSD_PL0"
  system_volume_size   = 50
  data_volumes {
    volume_type          = "ESSD_PL0"
    size                 = local.volume_size
    delete_with_instance = true
  }
  subnet_id          = volcengine_subnet.vke-tf-vsw.id
  security_group_ids = [volcengine_security_group.vke-tf-security-group.id]
  project_name       = "default"
  tags {
    key = "owner"
    value = "huangzhangshu"
  }
  lifecycle {
    ignore_changes = [security_group_ids, tags, instance_name]
  }
  count = local.node_count
}

resource "volcengine_vke_node" "vke-tf-node" {
  cluster_id   = volcengine_vke_cluster.vke-tf-cluster.id
  instance_id  = volcengine_ecs_instance.vke-tf-ecs-instance[count.index].id
  node_pool_id = volcengine_vke_node_pool.vke-tf-node-pool.id
  count        = local.node_count
}

data "volcengine_vke_nodes" "vke-tf-nodes" {
  ids = volcengine_vke_node.vke-tf-node[*].id
}

resource "volcengine_vke_kubeconfig" "vke-tf-kubeconfig-public" {
  cluster_id     = volcengine_vke_cluster.vke-tf-cluster.id
  type           = "Public"
  valid_duration = 24
}

data "volcengine_vke_kubeconfigs" "vke-tf-kubeconfigs" {
  ids = [volcengine_vke_kubeconfig.vke-tf-kubeconfig-public.id]
}

