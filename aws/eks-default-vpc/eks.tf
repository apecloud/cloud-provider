module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  cluster_iam_role_dns_suffix = "amazonaws.com"

  // KMS
  # create_kms_key                  = true
  # kms_key_deletion_window_in_days = 7
  create_kms_key                    = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/eks"
  }

  #cluster_enabled_log_types = local.cluster_enabled_log_types
  create_cloudwatch_log_group = false

  cluster_tags = {
     owner = local.owner
  }

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
  cluster_enabled_log_types      = []

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes to control plane on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules.
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node traffic on all ports in all protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_all = {
      description      = "All outbound traffic from nodes"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    # Allow control plane nodes to talk to worker nodes on all ports.
    # This can be restricted further to specific ports based on the requirement for each Add-on,
    # e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed.
    ingress_cluster_to_node_all_traffic = {
      description                   = "Control plane to node traffic on all ports"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

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
      subnet_ids = slice(data.aws_subnets.private.ids, 0, 1)
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

      tags = {
        owner      = local.owner
      }
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
