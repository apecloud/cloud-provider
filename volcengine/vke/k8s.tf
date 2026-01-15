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

  depends_on = [volcengine_vke_addon.csi-ebs]
}

resource "kubernetes_cluster_role_binding_v1" "role-feilian" {
  metadata {
    name = "feilian"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "vke:admin"
  }
  subject {
    kind      = "User"
    name      = "12181164-role" # this name is acquired from volcengine console's error meesage. I haven't found doc about it.
    api_group = "rbac.authorization.k8s.io"
  }
}
