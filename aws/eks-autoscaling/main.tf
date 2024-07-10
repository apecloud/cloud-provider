provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}


data "aws_ami" "amazon_eks_arm64" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.bottlerocket ?  "bottlerocket-aws-k8s-${local.cluster_version}-aarch64-*" : "amazon-eks-arm64-node-${local.cluster_version}-*"]
  }

  owners = ["amazon"]
}

data "aws_ami" "amazon_eks_x64" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.bottlerocket ? "bottlerocket-aws-k8s-${local.cluster_version}-x86_64-*" : "amazon-eks-node-${local.cluster_version}-*"]
  }

  owners = ["amazon"]
}

data "aws_partition" "current" {}
data "aws_availability_zones" "available" {}
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
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ec2_instance_type" "all" {
  for_each = local.all_instance_types

  instance_type = each.key
}

locals {
  name         = replace(basename(path.cwd), "[^a-zA-Z0-9]", "-")
  cluster_name = coalesce(var.cluster_name, local.name)
  partition    = data.aws_partition.current.partition
  dns_suffix   = data.aws_partition.current.dns_suffix
  region       = var.aws_region
  account_id   = data.aws_caller_identity.current.account_id
  ecr_dns      = "${local.account_id}.dkr.ecr.${local.region}.${local.dns_suffix}"

  cluster_role_name       = "${local.cluster_name}-eks-cluster-role"
  node_group_role_name    = "${local.cluster_name}-managed-node-role"
  cluster_admin_role_name = "${local.cluster_name}-admin-role"

  cluster_version = "1.30"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  on_demand_instance_types = setunion(
    toset([
      for pair in setproduct(
        toset(var.on_demand_instance_families),
        toset(var.on_demand_instance_sizes)
      ) : "${pair[0]}.${pair[1]}"
    ]),
    toset(var.on_demand_instance_types)
  )

  spot_instance_types = [
    for pair in setproduct(
      toset(concat(var.spot_arm64_instance_families, var.spot_amd64_instance_families)),
      toset(var.spot_instance_sizes)
    ) : "${pair[0]}.${pair[1]}"
  ]

  all_instance_types = setunion(
    toset([var.default_instance_type]),
    local.on_demand_instance_types,
    local.spot_instance_types
  )

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type
  # https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_ProcessorInfo.html
  instance_type_info = {
    for t in data.aws_ec2_instance_type.all : t.instance_type => {
      arch     = contains(t.supported_architectures, "arm64") ? "arm64" : "amd64"
      # TODO(fan): Upgrade to Amazon Linux 2023 once it is released.
      ami_type = "${var.bottlerocket ? "BOTTLEROCKET" : "AL2"}_${contains(t.supported_architectures, "arm64") ? "ARM_64" : "x86_64"}"
      ami_id   = contains(t.supported_architectures, "arm64") ? data.aws_ami.amazon_eks_arm64.id : data.aws_ami.amazon_eks_x64.id
      cpu      = t.default_vcpus
      memory   = "${t.memory_size}Mi"
      # TODO(fan): This field is only available for some instances with SSD storage.
      # storage  = "${t.total_instance_storage}Gi"
    }
  }

  addon_timeouts = {
    create = "10m"
    delete = "10m"
  }

  tags = {
    EKS        = local.cluster_name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
    Terraform  = "true"
    owner      = reverse(split("/", data.aws_caller_identity.current.arn))[0]

    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  k8s_labels = {
    EKS       = local.cluster_name
    Terraform = "true"
  }
}

#---------------------------------------------------------------
# EKS Cluster
#
# NOTE: Initially we used the EKS Blueprints module. However, it is announced that
# they will make breaking changes in forthcoming version 5. See:
#   https://github.com/aws-ia/terraform-aws-eks-blueprints/issues/1421
# In particular, they suggest using `terraform-aws-eks` module instead for cluster creation:
#   https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/docs/v5-direction/DIRECTION_v5.md#notable-changes
# So we should ALWAYS use `terraform-aws-eks` here.
# DO NOT go backwards, i.e., do not use EKS Blueprints anymore.
#---------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = local.cluster_name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

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
      service_account_role_arn = module.vpc_cni_ipv4_irsa_role.iam_role_arn

      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }

    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }
  cluster_addons_timeouts = local.addon_timeouts

  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = module.kms.key_arn
  }

  create_iam_role = false
  iam_role_arn    = aws_iam_role.eks_cluster.arn

  # By default, the audience is `sts.{local.dns_suffix}`. However, the IRSA submodule allows `sts.amazonaws.com` only.
  enable_irsa              = true
  openid_connect_audiences = ["sts.amazonaws.com"]

  # Use these settings instead if a new VPC is desired.
  # vpc_id                   = module.vpc.vpc_id
  # subnet_ids               = module.vpc.private_subnets
  # control_plane_subnet_ids = module.vpc.intra_subnets
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.private.ids

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

    # DO NOT use this in production environment
    # ingress_source_ssh = {
    #   description              = "SSH access from VPC private net to control plane"
    #   protocol                 = "tcp"
    #   from_port                = 22
    #   to_port                  = 22
    #   type                     = "ingress"
    #   source_security_group_id = aws_security_group.private_net_ssh.id
    # }
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

    # DO NOT use this in production environment
    # ingress_source_ssh = {
    #   description              = "SSH access from VPC private net to nodes"
    #   protocol                 = "tcp"
    #   from_port                = 22
    #   to_port                  = 22
    #   type                     = "ingress"
    #   source_security_group_id = aws_security_group.private_net_ssh.id
    # }

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

  # Default configurations for all EKS managed node groups
  eks_managed_node_group_defaults = {
    # Don't add timestamp suffix to names because doing this may lead to >63 characters.
    use_name_prefix = false

    create_iam_role = false
    iam_role_arn    = aws_iam_role.managed_ng.arn

    min_size     = 0
    desired_size = 0 # cluster autoscaler will update this dynamically.
    max_size     = var.auto_scaling_group_spot_max_size

    create_launch_template          = true
    platform                        = var.bottlerocket ? "bottlerocket" : "linux" # bottlerocket or linux
    launch_template_name            = "${local.cluster_name}-lt"
    launch_template_use_name_prefix = true # make LTs for different node groups distinguishable

    # Additional security groups to join.
    # vpc_security_group_ids = [aws_security_group.private_net_ssh.id]

    # Defaults to private subnet-ids used by EKS control plane.
    # subnet_ids  = []

    # SSH access. It is recommended to use SSM session manager instead.
    # remote_access = {
    #   ec2_ssh_key               = module.key_pair.key_pair_name
    #   source_security_group_ids = [aws_security_group.remote_access.id]
    # }

    # Only valid when using a custom AMI via ami_id. For bottlerocket platform with ami_id, it is neccesary:
    #   https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/user_data.md#eks-managed-node-group
    #   https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/modules/_user_data/main.tf
    enable_bootstrap_user_data = true

    # pre_bootstrap_user_data = <<-EOT
    #   yum install -y amazon-ssm-agent
    #   systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
    # EOT

    # post_bootstrap_user_data = <<-EOT
    #   echo "Bootstrap completed successfully!"
    # EOT

    # bootstrap_extra_args used only when you pass custom_ami_id.
    # e.g., bootstrap_extra_args="--use-max-pods false --container-runtime containerd"
    # Since EKS >=1.24, containerd is the only runtime in AWS official EKS AMI. See:
    #   https://docs.aws.amazon.com/eks/latest/userguide/dockershim-deprecation.html
    #
    # bootstrap_extra_args = "--container-runtime containerd"
    #
    # For bottlerocket platform, this option may be used to pass custom settings:
    #   https://github.com/bottlerocket-os/bottlerocket#kubernetes-settings
    # bootstrap_extra_args = <<-EOT
    #   [settings.kubernetes.node-labels]
    #   "os" = "bottlerocket"
    #   [settings.kubernetes.node-taints]
    #   "special" = ["true:NoSchedule"]
    # EOT

    enable_monitoring    = true
    force_update_version = true

    # The Kubernetes taints to be applied to the nodes in the node group.
    # taints = []

    labels = {
      Environment = "dev"
      Zone        = "dev"
      Runtime     = "containerd"
      GithubRepo  = "terraform-aws-eks"
      GithubOrg   = "terraform-aws-modules"
    }

    tags = {
      # This is so cluster autoscaler can identify which node groups (using ASGs tags) to scale through auto-discovery:
      #   https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#Auto-discovery-setup
      # The tag keys are customizable. We obey the default keys used in the above document, the official Helm Chart,
      #  the AWS guide, the `terraform-aws-iam` module and the `eksctl` tool:
      #   https://artifacthub.io/packages/helm/cluster-autoscaler/cluster-autoscaler
      #   https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html
      #   https://github.com/terraform-aws-modules/terraform-aws-iam/blob/master/modules/iam-role-for-service-accounts-eks/policies.tf
      "k8s.io/cluster-autoscaler/enabled"               = "true"
      "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
    }
  }

  eks_managed_node_groups = merge({
    # Managed node group with launch template using custom AMI
    "mng_default_${replace(var.default_instance_type, ".", "_")}" = {
      name = "${local.cluster_name}-mng-default-${replace(var.default_instance_type, ".", "-")}" # Max 40 characters for node group name

      # Use offical EKS-optimized AMI
      ami_type       = local.instance_type_info[var.default_instance_type].ami_type
      # ami_id         = local.instance_type_info[var.default_instance_type].ami_id
      capacity_type  = "SPOT" # ON_DEMAND or SPOT
      instance_types = [var.default_instance_type]

      # Node group scaling configuration
      desired_size = 3
      max_size     = var.auto_scaling_group_on_demand_max_size
      min_size     = 3
      update_config = {
        max_unavailable_percentage = 33
      }

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

      labels = {
        "resources/cpu"      = tostring(local.instance_type_info[var.default_instance_type].cpu)
        "resources/memory"   = local.instance_type_info[var.default_instance_type].memory
        "managed-node-group" = "default"
      }

      tags = {
        Arch         = local.instance_type_info[var.default_instance_type].arch
        CapacityType = "ON_DEMAND"
      }
    }
    },
    {
      for t in local.on_demand_instance_types : "mng_auto_scaling_${replace(t, ".", "_")}" => {
        name = "${local.cluster_name}-mng-auto-scaling-${replace(t, ".", "-")}"

        ami_type       = local.instance_type_info[t].ami_type
        # ami_id         = local.instance_type_info[t].ami_id
        capacity_type  = "SPOT"
        instance_types = [t]

        desired_size = 0
        max_size     = var.auto_scaling_group_on_demand_max_size
        min_size     = 0
        update_config = {
          max_unavailable_percentage = 33
        }

        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_type = "gp3"
              volume_size = 20
            }
          }
        ]

        taints = {
          autoscaler = {
            key    = "autoscaler"
            value  = "ClusterAutoscaler"
            effect = "NO_SCHEDULE"
          }
        }

        labels = {
          # Label cannot contain reserved prefixes [kubernetes.io/, k8s.io/, eks.amazonaws.com/]. See:
          #   https://github.com/aws/containers-roadmap/issues/1451
          # "kubernetes.io/arch"               = local.instance_type_info[t].arch
          # "node.kubernetes.io/instance-type" = t
          "resources/cpu"    = tostring(local.instance_type_info[t].cpu)
          "resources/memory" = local.instance_type_info[t].memory
        }

        tags = {
          Arch         = local.instance_type_info[t].arch
          CapacityType = "ON_DEMAND"

          "node.kubernetes.io/instance-type" = t

          # NOTE(fan): For Kubernetes <1.24, one have to tag the underlying Amazon EC2 Auto Scaling Groups with these details
          #   to enable scaling down to zero nodes. For EKS >=1.24, these tags is not neccesary once the `eks:DescribeNodegroup`
          #   permisson is given to the service account IAM role. See the 'Scaling from zero' subsection in
          #     https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html .
          #
          #   However, currently the Cluster Autoscaler will only call `eks:DescribeNodegroup` when a managed node group
          #   is created with 0 nodes and has **never** had any nodes added to it. See:
          #     https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws#minimal-iam-permissions-policy
          #     https://github.com/kubernetes/autoscaler/pull/4491
          #     https://github.com/kubernetes/autoscaler/commit/b4cadfb4e25b6660c41dbe2b73e66e9a2f3a2cc9
          #   I have observed that an EKS managed node group sometimes starts a node on its creation even if the desired size is zero.
          #   So we keep these tags until this precondition is removed.
          #
          # "k8s.io/cluster-autoscaler/node-template/label/kubernetes.io/arch"               = local.instance_type_info[t].arch
          # "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/instance-type" = t
          # "k8s.io/cluster-autoscaler/node-template/taint/autoscaler"                       = "ClusterAutoscaler:NoSchedule"
          # "k8s.io/cluster-autoscaler/node-template/resources/cpu"                          = tostring(local.instance_type_info[t].cpu)
          # "k8s.io/cluster-autoscaler/node-template/resources/memory"                       = local.instance_type_info[t].memory
          # "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage"            = local.instance_type_info[t].storage
          #
          # However (again), these tags cannot be propagated onto the underlying newly-created ASGs. See:
          #   https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1558
          # This problem may be addressed by an ongoing pull request:
          #   https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2457
          # Let's use the solution suggested by the author of this PR for now:
          #   https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2448#issuecomment-1420914467
          # TODO(fan): Recheck the status.
        }
      }
    },
    {
      # Managed node group with launch templates using custom AMI and ARM SPOT instances
      for instance_size in var.spot_instance_sizes : "mng_spot_arm_${instance_size}" => {
        name = "${local.cluster_name}-mng-spot-auto-scaling-arm-${instance_size}"

        ami_type       = "${var.bottlerocket ? "BOTTLEROCKET" : "AL2"}_ARM_64"
        # ami_id         = data.aws_ami.amazon_eks_arm64.id
        capacity_type  = "SPOT"
        instance_types = [for family in var.spot_arm64_instance_families : "${family}.${instance_size}"]

        taints = {
          spot = {
            key    = "spot"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
          autoscaler = {
            key    = "autoscaler"
            value  = "ClusterAutoscaler"
            effect = "NO_SCHEDULE"
          }
        }

        labels = {
          # "kubernetes.io/arch" = "arm64"
          "resources/cpu"    = tostring(local.instance_type_info["${var.spot_arm64_instance_families[0]}.${instance_size}"].cpu)
          "resources/memory" = local.instance_type_info["${var.spot_arm64_instance_families[0]}.${instance_size}"].memory
        }

        tags = {
          Arch         = "arm64"
          CapacityType = "SPOT"

          # "k8s.io/cluster-autoscaler/node-template/label/kubernetes.io/arch" = "arm64"
          # "k8s.io/cluster-autoscaler/node-template/taint/autoscaler"         = "ClusterAutoscaler:NoSchedule"
          # "k8s.io/cluster-autoscaler/node-template/taint/spot"               = "true:NoSchedule"
          # "k8s.io/cluster-autoscaler/node-template/resources/cpu"            = tostring(local.instance_type_info["${var.spot_arm64_instance_families[0]}.${instance_size}"].cpu)
          # "k8s.io/cluster-autoscaler/node-template/resources/memory"         = local.instance_type_info["${var.spot_arm64_instance_families[0]}.${instance_size}"].memory
        }
      }
    },
    {
      # Managed node group with launch templates using custom AMI and X86-64 SPOT instances
      for instance_size in var.spot_instance_sizes : "mng_spot_x64_${instance_size}" => {
        name = "${local.cluster_name}-mng-spot-auto-scaling-x64-${instance_size}"

        ami_type       = "${var.bottlerocket ? "BOTTLEROCKET" : "AL2"}_x86_64"
        # ami_id         = data.aws_ami.amazon_eks_x64.id
        capacity_type  = "SPOT"
        instance_types = [for family in var.spot_amd64_instance_families : "${family}.${instance_size}"]

        taints = {
          spot = {
            key    = "spot"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
          autoscaler = {
            key    = "autoscaler"
            value  = "ClusterAutoscaler"
            effect = "NO_SCHEDULE"
          }
        }

        labels = {
          # "kubernetes.io/arch" = "amd64"
          "resources/cpu"    = tostring(local.instance_type_info["${var.spot_amd64_instance_families[0]}.${instance_size}"].cpu)
          "resources/memory" = local.instance_type_info["${var.spot_amd64_instance_families[0]}.${instance_size}"].memory
        }

        tags = {
          Arch         = "amd64"
          CapacityType = "SPOT"

          # "k8s.io/cluster-autoscaler/node-template/label/kubernetes.io/arch" = "amd64"
          # "k8s.io/cluster-autoscaler/node-template/taint/autoscaler"         = "ClusterAutoscaler:NoSchedule"
          # "k8s.io/cluster-autoscaler/node-template/taint/spot"               = "true:NoSchedule"
          # "k8s.io/cluster-autoscaler/node-template/resources/cpu"            = tostring(local.instance_type_info["${var.spot_amd64_instance_families[0]}.${instance_size}"].cpu)
          # "k8s.io/cluster-autoscaler/node-template/resources/memory"         = local.instance_type_info["${var.spot_amd64_instance_families[0]}.${instance_size}"].memory
        }
      }
    }
  )

  manage_aws_auth_configmap = true

  aws_auth_roles = concat([
    {
      rolearn  = aws_iam_role.cluster_admin_auth_role.arn
      username = "admin:{{SessionName}}"
      groups   = ["system:masters"]
    },
    ], [
    for role_name in var.additional_admin_role_names : {
      rolearn  = "arn:${local.partition}:iam::${local.account_id}:role/${role_name}"
      username = "{{SessionName}}"
      groups   = ["system:masters"]
    }
  ])

  tags = local.tags
}


#---------------------------------------------------------------
# Supporting Resources
#
# VPC:
#   By default you are limited to 5 VPCs per region on AWS. See:
#     https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html
#   Ensure that you will not exceed the limit before enabling this section.
#---------------------------------------------------------------
#module "vpc" {
#  source  = "terraform-aws-modules/vpc/aws"
#  version = "~> 3.0"
#
#  name = local.name
#  cidr = local.vpc_cidr
#
#  azs             = local.azs
#  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
#  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]
#
#  enable_nat_gateway   = true
#  single_nat_gateway   = true
#  enable_dns_hostnames = true
#
#  # Manage so we can name
#  manage_default_network_acl    = true
#  default_network_acl_tags      = { Name = "${local.name}-default" }
#  manage_default_route_table    = true
#  default_route_table_tags      = { Name = "${local.name}-default" }
#  manage_default_security_group = true
#  default_security_group_tags   = { Name = "${local.name}-default" }
#
#  public_subnet_tags = {
#    "kubernetes.io/cluster/${local.name}" = "shared"
#    "kubernetes.io/role/elb"              = 1
#  }
#
#  private_subnet_tags = {
#    "kubernetes.io/cluster/${local.name}" = "shared"
#    "kubernetes.io/role/internal-elb"     = 1
#  }
#
#  tags = local.tags
#}


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

# Example of additional policies:
# data "aws_iam_policy_document" "describe_ec2" {
#   statement {
#     sid       = "DescribeEC2"
#     actions   = ["ec2:Describe*"]
#     resources = ["*"]
#   }
# }

resource "aws_iam_role" "eks_cluster" {
  name                  = local.cluster_role_name
  description           = "Allows access to other AWS service resources that are required to operate clusters managed by EKS."
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  managed_policy_arns = [
    "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  ]

  # inline_policy {
  #   name   = "DescribeEC2"
  #   policy = data.aws_iam_policy_document.describe_ec2.json
  # }

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
    "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  # inline_policy {
  #   name   = "DescribeEC2"
  #   policy = data.aws_iam_policy_document.describe_ec2.json
  # }

  tags = local.tags
}

#---------------------------------------------------------------
# IAM role for cluster authentication
#
# This allows other authorized users/roles in your account to access the cluster.
#   https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html
#   https://github.com/kubernetes-sigs/aws-iam-authenticator
#---------------------------------------------------------------

data "aws_iam_policy_document" "cluster_admin_auth_role_policy" {
  statement {
    sid = "EKSClusterAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "cluster_admin_auth_role" {
  name                  = local.cluster_admin_role_name
  description           = "Allows administrative accesses to EKS cluster ${local.cluster_name}"
  assume_role_policy    = data.aws_iam_policy_document.cluster_admin_auth_role_policy.json
  path                  = "/"
  force_detach_policies = true

  tags = local.tags
}

#---------------------------------------------------------------
# Example of additional security groups
#---------------------------------------------------------------
# resource "aws_security_group" "private_net_ssh" {
#   name_prefix = "${local.cluster_name}-private-net-ssh"
#   vpc_id      = data.aws_vpc.default.id

#   ingress {
#     from_port = 22
#     to_port   = 22
#     protocol  = "tcp"
#     cidr_blocks = [
#       "10.0.0.0/8",
#       "172.16.0.0/12",
#       "192.168.0.0/16",
#     ]
#   }

#   tags = merge(local.tags, { Name = "${local.name}-private-net-ssh" })
# }

resource "aws_iam_instance_profile" "managed_ng" {
  name = "${local.cluster_name}-mng-node-instance-profile"
  role = aws_iam_role.managed_ng.name
  path = "/"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

#---------------------------------------------------------------
# KMS for EKS control plane
#---------------------------------------------------------------
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~>1.1"

  aliases               = ["eks/${local.cluster_name}"]
  description           = "Encryption key for EKS cluster ${local.cluster_name}"
  enable_default_policy = true
  key_owners            = [data.aws_caller_identity.current.arn]

  tags = local.tags
}


#---------------------------------------------------------------
# SQS for AWS Node Termination Handler and Karpenter
#   https://github.com/aws/aws-node-termination-handler
#
# TODO(fan): Switch to the `terraform-aws-eks/modules/karpenter` submodule:
#   https://github.com/terraform-aws-modules/terraform-aws-eks/tree/master/modules/karpenter .
#   Currently, it uses `events.amazonaws.com.cn` and `sqs.amazonaws.com.cn`,
#   which cannot pass the validation in AWS China.
#---------------------------------------------------------------
data "aws_iam_policy_document" "ec2_change_queue_policy" {
  policy_id = "EC2ChangeQueuePolicy"

  statement {
    sid = "SendSQSMessage"

    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"] # .com.cn does not work
    }
    resources = ["arn:${local.partition}:sqs:${local.region}:${local.account_id}:${local.cluster_name}-ec2-change-queue"]
  }
}

resource "aws_sqs_queue" "ec2_change_queue" {
  name   = "${local.cluster_name}-ec2-change-queue"
  policy = data.aws_iam_policy_document.ec2_change_queue_policy.json

  tags = local.tags
}

module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~>1.17"

  bus_name = "${local.cluster_name}-ec2-state-bus"

  rules = {
    ASGTermRule = {
      description = "Capture ASG termination events"
      enabled     = true
      event_pattern = jsonencode({
        "source" : ["aws.autoscaling"],
        "detail-type" : ["EC2 Instance-terminate Lifecycle Action"]
      })
    }
    SpotTermRule = {
      description = "Capture EC2 Spot Interruptions"
      enabled     = true
      event_pattern = jsonencode({
        "source" : ["aws.ec2"],
        "detail-type" : ["EC2 Spot Instance Interruption Warning"]
      })
    }
    RebalanceRule = {
      description = "Capture EC2 Rebalance Recommendations"
      enabled     = true
      event_pattern = jsonencode({
        "source" : ["aws.ec2"],
        "detail-type" : ["EC2 Instance Rebalance Recommendation"]
      })
    }
    StateChangeRule = {
      description = "Capture EC2 State-change Notification"
      enabled     = true
      event_pattern = jsonencode({
        "source" : ["aws.ec2"],
        "detail-type" : ["EC2 Instance State-change Notification"]
      })
    }
    ScheduledChangeRule = {
      description = "Capture EC2 Scheduled Change Notification"
      enabled     = true
      event_pattern = jsonencode({
        "source" : ["aws.health"],
        "detail-type" : ["AWS Health Event"],
        "detail" : {
          "service" : ["EC2"],
          "eventTypeCategory" : ["scheduledChange"]
        }
      })
    }
  }

  targets = {
    ASGTermRule = [{
      name = "send-asg-term-to-sqs"
      arn  = aws_sqs_queue.ec2_change_queue.arn
    }]
    SpotTermRule = [{
      name = "send-spot-term-to-sqs"
      arn  = aws_sqs_queue.ec2_change_queue.arn
    }]
    RebalanceRule = [{
      name = "send-rebalance-to-sqs"
      arn  = aws_sqs_queue.ec2_change_queue.arn
    }]
    StateChangeRule = [{
      name = "send-state-change-to-sqs"
      arn  = aws_sqs_queue.ec2_change_queue.arn
    }]
    ScheduledChangeRule = [{
      name = "send-scheduled-change-to-sqs"
      arn  = aws_sqs_queue.ec2_change_queue.arn
    }]
  }

  tags = local.tags
}

#---------------------------------------------------------------
# IAM Roles for Service Accounts
#---------------------------------------------------------------

module "cert_manager_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>5.11"

  role_name                  = "${local.cluster_name}-cert-manager-irsa-role"
  attach_cert_manager_policy = true
  # TODO(fan): Change this
  cert_manager_hosted_zone_arns = ["arn:${local.partition}:route53:::hostedzone/todo.*"]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cert-manager"]
    }
  }

  tags = local.tags
}

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>5.11"

  role_name                        = "${local.cluster_name}-cluster-autoscaler-irsa-role"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.tags
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>5.11"

  role_name             = "${local.cluster_name}-ebs-csi-irsa-role"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

module "vpc_cni_ipv4_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>5.11"

  role_name             = "${local.cluster_name}-vpc-cni-ipv4"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

module "vpc_cni_ipv6_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>5.11"

  role_name             = "${local.cluster_name}-vpc-cni-ipv6"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

module "karpenter_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~>5.11"

  role_name                          = "${local.cluster_name}-karpenter-controller-irsa-role"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_id         = module.eks.cluster_name
  karpenter_controller_node_iam_role_arns = [aws_iam_role.managed_ng.arn]
  karpenter_sqs_queue_arn                 = aws_sqs_queue.ec2_change_queue.arn
  karpenter_controller_ssm_parameter_arns = ["arn:${local.partition}:ssm:*:*:parameter/aws/service/*"]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }

  tags = local.tags
}

# This is no longer needed because EKS managed node groups and Karpenter handle the termination natively. See:
#   https://github.com/aws/karpenter/pull/2546
#   https://github.com/terraform-aws-modules/terraform-aws-eks/pull/1994
# module "node_termination_handler_irsa_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = ">=5.11.1"

#   role_name                               = "${local.cluster_name}-node-termination-handler-irsa-role"
#   attach_node_termination_handler_policy  = true
#   node_termination_handler_sqs_queue_arns = [aws_sqs_queue.ec2_change_queue.arn]

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-node"]
#     }
#   }

#   tags = local.tags
# }


#---------------------------------------------------------------
# Install Helm Charts
#---------------------------------------------------------------
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.25.0"
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "awsRegion"
    value = local.region
  }

  # The AWS China document uses an `eks.amazonaws.com.cn/role-arn` annotation, but it does not work:
  #   https://docs.amazonaws.cn/eks/latest/userguide/associate-service-account-role.html
  # set {
  #   name  = "rbac.serviceAccount.annotations.eks\\.${replace(local.dns_suffix, ".", "\\.")}/role-arn"
  #   value = module.cluster_autoscaler_irsa_role.iam_role_arn
  # }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role.iam_role_arn
  }

  set {
    name  = "fullnameOverride"
    value = "cluster-autoscaler"
  }

  # Make it possible to run on control plane nodes. However it does not work on EKS.
  set {
    name  = "tolerations[0].key"
    value = "node-role.kubernetes.io/control-plane"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "nodeSelector.managed-node-group"
    value = "default"
  }

  # https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = var.cluster_autoscaler_scale_down_delay_after_add
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = var.cluster_autoscaler_scale_down_unneeded_time
  }

  set {
    name  = "extraArgs.scale-down-unready-time"
    value = var.cluster_autoscaler_scale_down_delay_after_add
  }

  set {
    name  = "extraArgs.cordon-node-before-terminating"
    value = true
  }

  set {
    name  = "extraArgs.max-graceful-termination-sec"
    value = 120
  }

  set {
    name  = "extraArgs.expander"
    value = "priority"
  }

  # It seems that the new registry.k8s.io is resolved to an address
  #   in an AWS region, but it still does not work in China.
  #   On my MacBook, it is resolved to asia-northeast1-docker.pkg.dev ,
  #   and in EKS cn-northwest-1, it is resolved to asia-east1-docker.pkg.dev .
  #   Both addresses is unaccessible in China.
  #   So we keep using ECR until it is not neccessary anymore.
  set {
    name  = "image.repository"
    value = "${local.ecr_dns}/autoscaling/cluster-autoscaler"
  }

  set {
    name  = "image.tag"
    value = "v1.26.1"
  }
}

# NOTE: In cn-northwest-1, Karpenter cannot get the on-demand EC2 prices. See:
#  https://github.com/aws/karpenter/issues/2846
#  https://github.com/aws/karpenter/issues/2706
resource "helm_release" "karpenter" {
  name             = "karpenter"
  chart            = "oci://public.ecr.aws/karpenter/karpenter"
  version          = "v0.26.1" # `v` is necessary.
  namespace        = "karpenter"
  create_namespace = true

  set {
    name  = "controller.image.repository"
    value = "${local.ecr_dns}/karpenter/controller"
  }
  set {
    name  = "controller.image.digest"
    value = ""
  }

  # The AWS China document uses an `eks.amazonaws.com.cn/role-arn` annotation, but it does not work:
  #   https://docs.amazonaws.cn/eks/latest/userguide/associate-service-account-role.html
  # set {
  #   name  = "serviceAccount.annotations.eks\\.${replace(local.dns_suffix, ".", "\\.")}/role-arn"
  #   value = module.karpenter_controller_irsa_role.iam_role_arn
  # }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_controller_irsa_role.iam_role_arn
  }

  set {
    name  = "nodeSelector.managed-node-group"
    value = "default"
  }

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.managed_ng.name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = aws_sqs_queue.ec2_change_queue.name
  }

  depends_on = [
    helm_release.cluster_autoscaler
  ]
}

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = "2.9.4"
  namespace        = "keda"
  create_namespace = true

  set {
    name  = "image.keda.repository"
    value = "${local.ecr_dns}/kedacore/keda"
  }
  set {
    name  = "image.keda.tag"
    value = "2.9.3"
  }

  set {
    name  = "image.metricsApiServer.repository"
    value = "${local.ecr_dns}/kedacore/keda-metrics-apiserver"
  }
  set {
    name  = "image.metricsApiServer.tag"
    value = "2.9.3"
  }

  set {
    name  = "nodeSelector.managed-node-group"
    value = "default"
  }

  depends_on = [
    helm_release.cluster_autoscaler
  ]
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.8.4"
  namespace        = "kube-system"

  set {
    name  = "image.repository"
    value = "${local.ecr_dns}/metrics-server/metrics-server"
  }

  set {
    name  = "metrics.enabled"
    value = true
  }
}

resource "helm_release" "kubernetes_dashboard" {
  name             = "kubernetes-dashboard"
  repository       = "https://kubernetes.github.io/dashboard/"
  chart            = "kubernetes-dashboard"
  version          = "6.0.0"
  namespace        = "kubernetes-dashboard"
  create_namespace = true

  set {
    name  = "image.repository"
    value = "${local.ecr_dns}/kubernetesui/dashboard"
  }
}
#---------------------------------------------------------------
# Install Kubernetes Resources
#
# NOTE: `kubernetes_manifest` has been tried, but it cannot work because the cluster
#   has to be accessible at plan time and thus cannot be created in the same apply operation.
#   See: https://github.com/hashicorp/terraform-provider-kubernetes/issues/1775
#---------------------------------------------------------------
resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1alpha1"
    kind       = "AWSNodeTemplate"

    metadata = {
      name      = "default-node-template"
      namespace = helm_release.karpenter.metadata[0].namespace
      labels = merge(local.k8s_labels, {
        "helm-release-revision/karpenter" = tostring(helm_release.karpenter.metadata[0].revision)
      })
    }

    spec = {
      amiFamily = var.bottlerocket ? "Bottlerocket" : "AL2"
      subnetSelector = {
        "aws-ids" = join(",", data.aws_subnets.private.ids)
      }
      securityGroupSelector = {
        "kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
      }
      tags = {
        "EKS" = module.eks.cluster_name
        # This tag is **necessary** because it is used in the conditions of IRSA role.
        "karpenter.sh/discovery" = module.eks.cluster_name
      }
    }
  })

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_on_demand_provisioner" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"

    metadata = {
      name      = "on-demand-default"
      namespace = helm_release.karpenter.metadata[0].namespace
      labels = merge(local.k8s_labels, {
        "helm-release-revision/karpenter" = tostring(helm_release.karpenter.metadata[0].revision)
      })
    }

    spec = {
      providerRef = {
        name = kubectl_manifest.karpenter_node_template.name
      }

      taints = [
        {
          key    = "autoscaler"
          value  = "Karpenter"
          effect = "NoSchedule"
        }
      ]

      requirements = [
        {
          key      = "karpenter.k8s.aws/instance-family"
          operator = "In"
          values   = var.karpenter_on_demand_instance_families
        },
        {
          key      = "karpenter.k8s.aws/instance-family"
          operator = "In"
          values   = var.karpenter_on_demand_instance_families
        },
        {
          key      = "karpenter.k8s.aws/instance-size"
          operator = "In"
          values   = var.karpenter_on_demand_instance_sizes
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["on-demand"]
        }
      ]

      limits = {
        resources = {
          cpu = var.karpenter_on_demand_cpu_limit
        }
      }

      consolidation = {
        enabled = true
      }
      # ttlSecondsAfterEmpty = 30

      weight = 10
    }
  })

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_template
  ]
}

resource "kubectl_manifest" "karpenter_spot_provisioner" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"

    metadata = {
      name      = "spot-default"
      namespace = helm_release.karpenter.metadata[0].namespace
      labels = merge(local.k8s_labels, {
        "helm-release-revision/karpenter" = tostring(helm_release.karpenter.metadata[0].revision)
      })
    }

    spec = {
      providerRef = {
        name = kubectl_manifest.karpenter_node_template.name
      }

      taints = [
        {
          key    = "autoscaler"
          value  = "Karpenter"
          effect = "NoSchedule"
        },
        {
          key    = "spot"
          value  = "true"
          effect = "NoSchedule"
        },
      ]

      requirements = [
        {
          key      = "karpenter.k8s.aws/instance-family"
          operator = "In"
          values   = var.karpenter_spot_instance_families
        },
        {
          key      = "karpenter.k8s.aws/instance-family"
          operator = "In"
          values   = var.karpenter_spot_instance_families
        },
        {
          key      = "karpenter.k8s.aws/instance-size"
          operator = "In"
          values   = var.karpenter_spot_instance_sizes
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot"]
        }
      ]

      limits = {
        resources = {
          cpu = var.karpenter_spot_cpu_limit
        }
      }

      consolidation = {
        enabled = true
      }
      # ttlSecondsAfterEmpty = 30
      # ttlSecondsUntilExpired = 3600

      weight = 20
    }
  })

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_template
  ]
}

# https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/expander/priority
# TODO(fan): Add overprovision?
#   https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#how-can-i-configure-overprovisioning-with-cluster-autoscaler
resource "kubernetes_config_map" "cluster_autoscaler_priority" {
  metadata {
    name      = "cluster-autoscaler-priority-expander"
    namespace = "kube-system"
    labels = merge(local.k8s_labels, {
      "helm-release-revision/cluster-autoscaler" = tostring(helm_release.cluster_autoscaler.metadata[0].revision)
    })
  }

  data = {
    priorities = var.cluster_autoscaler_priorities
  }
}

resource "kubernetes_service_account" "kubernetes_dashboard_user" {
  metadata {
    namespace = "kubernetes-dashboard"
    name      = "admin-user"
  }
}

resource "kubernetes_cluster_role_binding" "kubernetes_dashboard_role_binding" {
  metadata {
    name = "kubernetes-dashboard-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    namespace = "kubernetes-dashboard"
    name      = "admin-user"
  }
}
#---------------------------------------------------------------
# Add Cluster Autoscaler tags to EC2 Auto Scaling Groups
#
# This block can be removed once the following pull request is accepted:
#   https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2457
#---------------------------------------------------------------
locals {
  node_label_tag_prefix    = "k8s.io/cluster-autoscaler/node-template/label/"
  node_taint_tag_prefix    = "k8s.io/cluster-autoscaler/node-template/taint/"
  node_resource_tag_prefix = "k8s.io/cluster-autoscaler/node-template/"

  node_labels = flatten([for k, v in module.eks.eks_managed_node_groups : [
    for l, w in v.node_group_labels : {
      id : "${k}/${l}"
      name : v.node_group_autoscaling_group_names[0]
      key : l
      value : w
    } if !startswith(l, "resources/")
  ] if length(v.node_group_labels) > 0])

  node_taints = flatten([for k, v in module.eks.eks_managed_node_groups : [
    for l, w in v.node_group_taints : {
      id : "${k}/${w.key}"
      name : v.node_group_autoscaling_group_names[0]
      key : w.key
      value : w.value
      effect : replace(title(lower(replace(w.effect, "_", " "))), " ", "")
    }
  ] if length(v.node_group_taints) > 0])

  node_resources = flatten([for k, v in module.eks.eks_managed_node_groups : [
    for l, w in v.node_group_labels : {
      id : "${k}/${l}"
      name : v.node_group_autoscaling_group_names[0]
      key : l
      value : w
    } if startswith(l, "resources/")
  ] if length(v.node_group_labels) > 0])
}

resource "aws_autoscaling_group_tag" "labels" {
  for_each = {
    for k, v in local.node_labels :
    v.id => v
  }
  autoscaling_group_name = each.value.name
  tag {
    key                 = "${local.node_label_tag_prefix}${each.value.key}"
    propagate_at_launch = true
    value               = each.value.value
  }
}

resource "aws_autoscaling_group_tag" "taints" {
  for_each = {
    for k, v in local.node_taints :
    v.id => v
  }
  autoscaling_group_name = each.value.name
  tag {
    key                 = "${local.node_taint_tag_prefix}${each.value.key}"
    propagate_at_launch = true
    value               = "${each.value.value}:${each.value.effect}"
  }
}

resource "aws_autoscaling_group_tag" "resources" {
  for_each = {
    for k, v in local.node_resources :
    v.id => v
  }
  autoscaling_group_name = each.value.name
  tag {
    key                 = "${local.node_resource_tag_prefix}${each.value.key}"
    propagate_at_launch = true
    value               = each.value.value
  }
}
