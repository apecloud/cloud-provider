module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  cluster_iam_role_dns_suffix = "amazonaws.com"

  cluster_enabled_log_types = local.cluster_enabled_log_types

  cluster_addons = {
    coredns = {
      preserve    = true
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent              = true
    }

    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  create_iam_role = false
  iam_role_arn    = aws_iam_role.eks_cluster.arn

  cluster_addons_timeouts = local.addon_timeouts

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.private.ids
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    one = {
      name = local.node_group_name
      use_name_prefix = false

      ami_type = local.ami_type # AL2_ARM_64,AL2_x86_64
      instance_types = local.instance_types  # t4g.medium,t3a.medium
      capacity_type  = local.capacity_type # ON_DEMAND or SPOT

      create_iam_role = false
      iam_role_arn    = aws_iam_role.managed_ng.arn

      min_size     = local.min_size
      max_size     = local.max_size
      desired_size = local.desired_size
      update_config = {
         max_unavailable_percentage = 33
      }

      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_type = "gp3"
            volume_size = local.volume_size
          }
        }
      ]
    }
  }
}

resource "null_resource" "storageclass-patch" {
  depends_on = [
    module.eks
  ]

  provisioner "local-exec" {
    command = "script/sc-patch.sh ${local.region} ${local.cluster_name}"
  }
}
