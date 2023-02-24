module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.24"
  cluster_iam_role_dns_suffix = "amazonaws.com"

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = (var.region == "cn-north-1") || (var.region == "cn-northwest-1") ? "arn:aws-cn:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" : "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }

  eks_managed_node_groups = {
    one = {
      name = "kb-ng-1"
      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "kb-ng-2"
      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}

resource "null_resource" "storageclass-patch" {
  depends_on = [
    module.eks
  ]

  provisioner "local-exec" {
    command = "script/sc-patch.sh ${var.region} ${module.eks.cluster_name}"
  }
}
