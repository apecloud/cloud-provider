locals {
  lb_vpc = tencentcloud_vpc.this.id
  lb_sg  = tencentcloud_security_group.this.id
}

resource "tencentcloud_clb_instance" "ingress-lb" {
  address_ip_version           = "ipv4"
  clb_name                     = "${var.cluster_name}-lb"
  load_balancer_pass_to_target = true
  network_type                 = "OPEN"
  security_groups              = [local.lb_sg]
  vpc_id                       = local.lb_vpc
  tags                         = {
    tke-clusterId = module.tke.cluster_id
  }
}
