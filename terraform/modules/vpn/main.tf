# Site-to-site VPN add-on — enable when client selects VPN connectivity.
# Wire into environments/prod/main.tf after filling customer gateway details.

variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "private_route_table_ids" { type = list(string) }
variable "customer_gateway_ip" { type = string }
variable "customer_network_cidr" { type = string }

resource "aws_customer_gateway" "this" {
  bgp_asn    = 65000
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.name_prefix}-cgw"
  }
}

resource "aws_vpn_gateway" "this" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-vgw"
  }
}

resource "aws_vpn_connection" "this" {
  vpn_gateway_id      = aws_vpn_gateway.this.id
  customer_gateway_id = aws_customer_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "${var.name_prefix}-vpn"
  }
}

resource "aws_vpn_connection_route" "customer" {
  destination_cidr_block = var.customer_network_cidr
  vpn_connection_id      = aws_vpn_connection.this.id
}

resource "aws_route" "private_to_customer" {
  count = length(var.private_route_table_ids)

  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = var.customer_network_cidr
  gateway_id             = aws_vpn_gateway.this.id
}

output "vpn_connection_id" {
  value = aws_vpn_connection.this.id
}
