module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name                = local.cluster_name
  cluster_version             = "1.25"
  cluster_iam_role_dns_suffix = "amazonaws.com"

  cluster_addons = {
    # we only has one node group that has one node for kubernetes control plane,
    # so we need to set the default replicas to 1
    aws-ebs-csi-driver = {
      most_recent          = true
      configuration_values = yamlencode({
        controller = {
          # csi driver controller does not support to specify the replica count, the default replica count is 2,
          # so, we should tolerate all taints, otherwise the controller will not be able to schedule on tainted nodes
          tolerations = [
            {
              operator = "Exists"
            }
          ]
        }
      })
    }
    coredns = {
      most_recent          = true
      configuration_values = yamlencode({
        replicaCount = 1
      })
    }
  }

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = var.arch == "arm64" ? "AL2_ARM_64" : "AL2_x86_64"

    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = (var.region == "cn-north-1") || (var.region == "cn-northwest-1") ? "arn:aws-cn:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" : "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }

  node_security_group_additional_rules = {
    grafana = {
      description                   = "grafana"
      protocol                      = "tcp"
      from_port                     = 3000
      to_port                       = 3000
      type                          = "ingress"
      source_cluster_security_group = true
    }

    prometheus = {
      description                   = "prometheus"
      protocol                      = "tcp"
      from_port                     = 9090
      to_port                       = 9090
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_groups = {
    kube-system = {
      name                  = "kube-system"
      # control plane use a smaller instance type to save cost
      # t3.medium is 2c4g
      instance_types        = ["t3.medium"]
      capacity_type         = var.capacity_type
      min_size              = 1
      max_size              = 3
      desired_size          = 1
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

    control-plane = {
      name                  = "kb-control-plane"
      # control plane use a smaller instance type to save cost
      # t3.medium is 2c4g
      instance_types        = ["t3.medium"]
      capacity_type         = var.capacity_type
      min_size              = 1
      max_size              = 3
      desired_size          = 1
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
      taints = [
        {
          key    = "kb-controller"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      labels = {
        "kb-controller" = "true"
      }
    }

    data-plane = {
      name                  = "kb-data-plane"
      instance_types        = [var.instance_type]
      capacity_type         = var.capacity_type
      min_size              = 1
      max_size              = 5
      desired_size          = 4
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
      taints = [
        {
          key    = "kb-data"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      labels = {
        "kb-data" = "true"
      }
    }
  }
}

resource "null_resource" "post-create" {
  depends_on = [
    module.eks
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "script/post-create.sh ${var.region} ${module.eks.cluster_name} ${module.eks.cluster_arn}"
  }
}

resource "null_resource" "on-destroy" {
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "script/destroy.sh"
  }
}
