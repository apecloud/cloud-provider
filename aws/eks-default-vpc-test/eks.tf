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
data "aws_region" "current" {}

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
}

resource "null_resource" "storageclass-patch" {
  depends_on = [
    module.eks
  ]

  provisioner "local-exec" {
    command = "script/sc-patch.sh ${local.region} ${local.cluster_name}"
  }
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
      "sts:AssumeRole"
#      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name                  = local.cluster_role_name
  description           = "Allows access to other AWS service resources that are required to operate clusters managed by EKS."
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  tags                  = local.tags
}

# Define each policy attachment as a separate resource
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

#resource "aws_iam_role_policy_attachment" "eks_block_storage_policy" {
#  role       = aws_iam_role.eks_cluster.name
#  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSBlockStoragePolicy"
#}

#resource "aws_iam_role_policy_attachment" "eks_compute_policy" {
#  role       = aws_iam_role.eks_cluster.name
#  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSComputePolicy"
#}

#resource "aws_iam_role_policy_attachment" "eks_load_balancing_policy" {
#  role       = aws_iam_role.eks_cluster.name
#  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
#}

#resource "aws_iam_role_policy_attachment" "eks_networking_policy" {
#  role       = aws_iam_role.eks_cluster.name
#  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSNetworkingPolicy"
#}

#---------------------------------------------------------------
# Custom IAM role for Node Groups
#---------------------------------------------------------------
data "aws_iam_policy_document" "managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole"
#      "sts:TagSession"
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
  tags = local.tags
}

# Define each policy attachment as a separate resource
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.managed_ng.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.managed_ng.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_policy" {
  role       = aws_iam_role.managed_ng.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "cicd_node_group" {
  cluster_name    = module.eks.cluster_name
  node_group_name = local.node_group_name
  ami_type        = local.ami_type # AL2_ARM_64,AL2_x86_64
  instance_types  = local.instance_types  # t4g.medium,t3a.medium
  capacity_type   = local.capacity_type # ON_DEMAND or SPOT
  node_role_arn   = aws_iam_role.managed_ng.arn
  subnet_ids      = data.aws_subnets.private.ids
  # subnet_ids = slice(data.aws_subnets.private.ids, 0, 1)
  disk_size       = local.volume_size
  scaling_config {
    desired_size  = local.desired_size
    max_size      = local.max_size
    min_size      = local.min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_policy,
  ]

  tags = {
    owner         = local.owner
  }

}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  depends_on = [
    aws_eks_node_group.cicd_node_group
  ]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  depends_on = [
    aws_eks_node_group.cicd_node_group
  ]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  depends_on = [
    aws_eks_node_group.cicd_node_group
  ]
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  depends_on = [
    aws_eks_node_group.cicd_node_group
  ]
}
