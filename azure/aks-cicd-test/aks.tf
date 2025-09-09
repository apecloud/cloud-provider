# AKS cluster
provider "azurerm" {
  # skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
  subscription_id = local.subscription_id
}

resource "random_pet" "prefix" {}

resource "azurerm_resource_group" "default" {
  name     = "${local.cluster_name}-group"
  location = local.region

  tags = {
    environment = "cicd-test"
    owner = "huangzhangshu"
  }
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = local.cluster_name
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = "${random_pet.prefix.id}-k8s"
  kubernetes_version  = local.cluster_version

  default_node_pool {
    name            = "default"
    node_count      = 1
    vm_size         = "Standard_B2s"
    os_disk_size_gb = 50
    auto_scaling_enabled = false
  }

  service_principal {
    client_id     = local.appId
    client_secret = local.password
  }

  role_based_access_control_enabled = true

  tags = {
    environment = "cicd-test"
    owner = "huangzhangshu"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "test-pool" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.default.id
  name                  = local.node_pool_name
  vm_size               = local.machine_type
  node_count            = local.node_count
  os_disk_size_gb       = local.disk_size_gb
  auto_scaling_enabled = true
  node_public_ip_enabled = true
  max_count             = 33
  min_count             = 3
#  priority              = "Spot" # Spot|Regular
#  eviction_policy       = "Delete"
#  spot_max_price        = 0.5 # note: this is the "maximum" price
#  node_labels = {
#    "kubernetes.azure.com/scalesetpriority" = "spot"
#  }
   node_labels = {
     "owner" = "huangzhangshu"
   }

  tags = {
    environment = "cicd-test"
    owner = "huangzhangshu"
  }
}
