#####
# hack for region cn-north-1
#####
locals {
  tmp_available_zones = (var.region == "cn-north-1") && length(var.available_zones) == 0 ? ["cn-north-1a", "cn-north-1b"] : var.available_zones
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "kb-vpc"

  cidr = "10.0.0.0/16"

  azs  = length(local.tmp_available_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, 3) : slice(local.tmp_available_zones, 0, length(local.tmp_available_zones))

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}
