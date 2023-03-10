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
    ami_type = "AL2_x86_64"

    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = (var.region == "cn-north-1") || (var.region == "cn-northwest-1") ? "arn:aws-cn:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" : "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }

  eks_managed_node_groups = {
    kb-ng = {
      name                  = "kb-ng"
      instance_types        = ["t3.large"]
      capacity_type         = "ON_DEMAND" # ON_DEMAND or SPOT
      min_size              = 1
      max_size              = 5
      desired_size          = 3
      ebs_optimized         = true
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs         = {
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