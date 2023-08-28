# GKE cluster
resource "google_container_cluster" "this" {
  name     = local.cluster_name

  # single-zone cluster for KubeBlocks
  # multi-zona cluster with single control plane and cross-zone nodes
  # regional cluster with multi control plane and cross-zone nodes
  #location = local.region
  location = local.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  min_master_version       = local.cluster_version

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "this" {
  name       = google_container_cluster.this.name
  # for regional cluster, nodepool is replicated in zones
  #location   = local.region
  location   = local.zone
  cluster    = google_container_cluster.this.name
  node_count = local.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      app = "${local.cluster_name}-node"
    }

    disk_size_gb = local.disk_size_gb
    spot         = local.spot

    # preemptible  = true
    # https://cloud.google.com/compute/docs/general-purpose-machines?hl=zh-cn
    # machine_type = "e2-standard-4" # 4 vCPU, 16 GB memory
    machine_type = local.machine_type
    tags         = ["gke-node", local.cluster_name]
    metadata     = {
      disable-legacy-endpoints = "true"
    }
  }
}