# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

# Auto-create subnet if not provided
resource "aws_subnet" "main" {
  count = local.create_subnet ? 1 : 0

  vpc_id                          = var.vpc_id
  availability_zone               = data.aws_availability_zones.available.names[0]
  cidr_block                      = var.enable_ipv4 ? cidrsubnet(data.aws_vpc.selected.cidr_block, 8, 0) : null
  ipv6_cidr_block                 = cidrsubnet(data.aws_vpc.selected.ipv6_cidr_block, 8, 0)
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = var.enable_ipv4

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet"
    }
  )
}
