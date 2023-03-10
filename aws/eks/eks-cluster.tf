module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name                = local.cluster_name
  cluster_version             = "1.25"
  cluster_iam_role_dns_suffix = "amazonaws.com"

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_ARM_64"

    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy =  (var.region == "cn-northwest-1") ? "arn:aws-cn:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" : "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }

  eks_managed_node_groups = {
    one = {
      name           = "kb-ng-1"
      instance_types = ["t4g.small"]

      capacity_type  = "SPOT" # ON_DEMAND or SPOT
      min_size     = 1
      max_size     = 3
      desired_size = 2
      ebs_optimized = true
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_type = "gp3"
            volume_size = 20
          }
        }
      ]
    }

    two = {
      name           = "kb-ng-2"
      instance_types = ["t4g.small"]
      capacity_type  = "SPOT" # ON_DEMAND or SPOT
      min_size     = 1
      max_size     = 2
      desired_size = 1
      ebs_optimized = true
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_type = "gp3"
            volume_size = 20
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
    command = "script/sc-patch.sh ${var.region} ${module.eks.cluster_name} ${module.eks.cluster_arn}"
  }
}

resource "null_resource" "on-destroy" {
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "script/destroy.sh"
  }
}