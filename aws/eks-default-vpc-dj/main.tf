# Kubernetes provider
# https://learn.hashicorp.com/terraform/kubernetes/provision-eks-cluster#optional-configure-terraform-kubernetes-provider
# To learn how to schedule deployments and services using the provider, go here: https://learn.hashicorp.com/terraform/kubernetes/deploy-nginx-kubernetes
# The Kubernetes provider is included in this file so the EKS module can complete successfully. Otherwise, it throws an error when creating `kubernetes_config_map.aws_auth`.
# You should **not** schedule deployments and services in this workspace. This keeps workspaces modular (one for provision EKS, another for scheduling Kubernetes resources) as per best practices.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
}

provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# If a new VPC is desired, please disable these two queries and enable the vpc module.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  #filter {
  #  name   = "default-for-az"
  #  values = ["true"]
  #}
}


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

#---------------------------------------------------------------
# Custom IAM role for EKS Cluster

# By default, the AWS modules use "eks.amazonaws.com.cn" as the service principal when creating the cluster role.
# However this doesn't work because AWS China expects "eks.amazonaws.com" for this case.
# See: https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1904
#---------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role_policy" {
  statement {
    sid = "EKSClusterAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"] # .com.cn does not work
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name                  = local.cluster_role_name
  description           = "Allows access to other AWS service resources that are required to operate clusters managed by EKS."
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  managed_policy_arns = [
    "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]

  tags = local.tags
}

#---------------------------------------------------------------
# Custom IAM role for Node Groups
#---------------------------------------------------------------
data "aws_iam_policy_document" "managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.${local.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "managed_ng" {
  name                  = local.node_group_role_name
  description           = "Allows EC2 instances to call AWS services on your behalf."
  assume_role_policy    = data.aws_iam_policy_document.managed_ng_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  managed_policy_arns = [
    "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]

  tags = local.tags
}
