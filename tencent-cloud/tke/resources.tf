# It is recommended to use the vpc module to create vpc and subnets
resource "tencentcloud_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  name       = "${var.cluster_name}-vpc"
}

resource "tencentcloud_subnet" "this" {
  cidr_block        = "10.0.1.0/24"
  name              = "${var.cluster_name}-subnet"
  availability_zone = local.available_zone
  vpc_id            = tencentcloud_vpc.this.id
}

# It is recommended to use the security group module to create security group and rules
resource "tencentcloud_security_group" "this" {
  name = "${var.cluster_name}-sg"
}

resource "tencentcloud_security_group_lite_rule" "this" {
  security_group_id = tencentcloud_security_group.this.id

  ingress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL",
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL",
  ]
}
