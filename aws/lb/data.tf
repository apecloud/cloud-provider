data "aws_eks_cluster" "eks" {
    name = var.cluster_name
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}