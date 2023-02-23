# Policy
locals {
  region = data.aws_region.current.name
  oidc_issuer = split("/", data.aws_eks_cluster.eks.identity[0].oidc[0].issuer)
  oidc_id = element(local.oidc_issuer, length(local.oidc_issuer) - 1)
  partition = data.aws_partition.current.partition
  dns_suffix = data.aws_partition.current.dns_suffix
  # partition = (local.region == "cn-north-1" || local.region == "cn-northwest-1") ? "aws-cn" : "aws"
  # domain_suffix = (local.region == "cn-north-1" || local.region == "cn-northwest-1") ? "com.cn" : "com"
}

data "aws_iam_policy_document" "lb_controller" {
  count = var.enabled ? 1 : 0

  statement {
    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"

      values = [
        "elasticloadbalancing.amazonaws.com"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:CreateSecurityGroup"
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "arn:${local.partition}:ec2:*:*:security-group/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"

      values = [
        "CreateSecurityGroup"
      ]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"

      values = [
        "false"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]

    resources = [
      "arn:${local.partition}:ec2:*:*:security-group/*"
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"

      values = [
        "true"
      ]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"

      values = [
        "false"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"

      values = [
        "false"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"

      values = [
        "false"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = [
      "*",
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]

    resources = [
      "arn:${local.partition}:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:${local.partition}:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:${local.partition}:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"

      values = [
        "true"
      ]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"

      values = [
        "false"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:${local.partition}:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:${local.partition}:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:${local.partition}:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:${local.partition}:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"

      values = [
        "false"
      ]
    }

    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = [
      "arn:${local.partition}:elasticloadbalancing:*:*:targetgroup/*/*"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = [
      "*"
    ]
    effect = "Allow"
  }

}

resource "aws_iam_policy" "lb_controller" {
  depends_on  = [var.mod_dependency]
  count       = var.enabled ? 1 : 0
  name        = "${var.cluster_name}-alb-ingress"
  path        = "/"
  description = "Policy for alb-ingress service"

  policy = data.aws_iam_policy_document.lb_controller[0].json
}

# Role
data "aws_iam_policy_document" "lb_controller_assume" {
  count = var.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:${local.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${data.aws_region.current.name}.${local.dns_suffix}/id/${local.oidc_id}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.namespace}:${var.service_account_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "lb_controller" {
  count              = var.enabled ? 1 : 0
  name               = "${var.cluster_name}-alb-ingress"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume[0].json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.lb_controller[0].name
  policy_arn = aws_iam_policy.lb_controller[0].arn
}
