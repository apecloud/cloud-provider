locals {
  region                    = var.region
  name                      = "cicd-eks-${random_string.suffix.result}"
  cluster_name              = coalesce(var.cluster_name, local.name)
  cluster_version           = var.cluster_version
  node_group_name           = var.node_group_name
  partition                 = data.aws_partition.current.partition
  dns_suffix                = data.aws_partition.current.dns_suffix
  cluster_role_name         = coalesce(var.cluster_role_name, "${local.cluster_name}-cluster-role")
  node_group_role_name      = coalesce(var.node_group_role_name, "${local.cluster_name}-node-group-role")
  azs                       = slice(data.aws_availability_zones.available.names, 0, 3)
  cluster_enabled_log_types = var.cluster_enabled_log_types
  instance_types            = var.instance_types
  ami_type                  = var.ami_type
  capacity_type             = var.capacity_type
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_size              = var.desired_size
  volume_size               = var.volume_size
  owner                     = reverse(split("/", data.aws_caller_identity.current.arn))[0]

  addon_timeouts = {
    create = "20m"
    delete = "20m"
  }

  tags = {
    EKS        = local.cluster_name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
    Terraform  = "true"
    owner      = local.owner

    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}