variable "enabled" {
  type        = bool
  default     = true
  description = "Variable indicating whether deployment is enabled."
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}

variable "helm_chart_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "AWS Load Balancer Controller Helm chart name."
}

variable "helm_chart_release_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "AWS Load Balancer Controller Helm chart release name."
}

variable "helm_chart_repo" {
  type        = string
  default     = "https://aws.github.io/eks-charts"
  description = "AWS Load Balancer Controller Helm repository name."
}

variable "helm_chart_version" {
  type        = string
  default     = "1.4.4"
  description = "AWS Load Balancer Controller Helm chart version."
}

variable "image_registries" {
  type        = map(string)
  default = {
    # copied from https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
    "af-south-1" = "877085696533.dkr.ecr.af-south-1.amazonaws.com"
    "ap-east-1" = "800184023465.dkr.ecr.ap-east-1.amazonaws.com"
    "ap-northeast-1" = "602401143452.dkr.ecr.ap-northeast-1.amazonaws.com"
    "ap-northeast-2" = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com"
    "ap-northeast-3" = "602401143452.dkr.ecr.ap-northeast-3.amazonaws.com"
    "ap-south-1" = "602401143452.dkr.ecr.ap-south-1.amazonaws.com"
    "ap-southeast-1" = "602401143452.dkr.ecr.ap-southeast-1.amazonaws.com"
    "ap-southeast-2" = "602401143452.dkr.ecr.ap-southeast-2.amazonaws.com"
    "ap-southeast-3" = "296578399912.dkr.ecr.ap-southeast-3.amazonaws.com"
    "ca-central-1" = "602401143452.dkr.ecr.ca-central-1.amazonaws.com"
    "cn-northwest-1" = "961992271922.dkr.ecr.cn-northwest-1.amazonaws.com.cn"
    "eu-central-1" = "602401143452.dkr.ecr.eu-central-1.amazonaws.com"
    "eu-north-1" = "602401143452.dkr.ecr.eu-north-1.amazonaws.com"
    "eu-south-1" = "590381155156.dkr.ecr.eu-south-1.amazonaws.com"
    "eu-west-1" = "602401143452.dkr.ecr.eu-west-1.amazonaws.com"
    "eu-west-2" = "602401143452.dkr.ecr.eu-west-2.amazonaws.com"
    "eu-west-3" = "602401143452.dkr.ecr.eu-west-3.amazonaws.com"
    "me-south-1" = "558608220178.dkr.ecr.me-south-1.amazonaws.com"
    "me-central-1" = "759879836304.dkr.ecr.me-central-1.amazonaws.com"
    "sa-east-1" = "602401143452.dkr.ecr.sa-east-1.amazonaws.com"
    "us-east-1" = "602401143452.dkr.ecr.us-east-1.amazonaws.com"
    "us-east-2" = "602401143452.dkr.ecr.us-east-2.amazonaws.com"
    "us-gov-east-1" = "151742754352.dkr.ecr.us-gov-east-1.amazonaws.com"
    "us-gov-west-1" = "013241004608.dkr.ecr.us-gov-west-1.amazonaws.com"
    "us-west-1" = "602401143452.dkr.ecr.us-west-1.amazonaws.com"
    "us-west-2" = "602401143452.dkr.ecr.us-west-2.amazonaws.com"
  }
  description = "AWS Load Balancer Controller image registry."
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create Kubernetes namespace with name defined by `namespace`."
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "AWS Load Balancer Controller Helm chart namespace which the service will be created."
}

variable "service_account_name" {
  type        = string
  default     = "aws-alb-ingress-controller"
  description = "The kubernetes service account name."
}

variable "mod_dependency" {
  type        = any
  default     = null
  description = "Dependence variable binds all AWS resources allocated by this module, dependent modules reference this variable."
}

variable "settings" {
  type        = any
  default     = {}
  description = "Additional settings which will be passed to the Helm chart values, see https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller#configuration."
}

variable "roles" {
  type = list(object({
    name      = string
    namespace = string
    secrets   = list(string)
  }))
  default     = []
  description = "RBAC roles that give secret access in other namespaces to the lb controller"
}
