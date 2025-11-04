# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

locals {
  # Parse hostname and port from oidc_addr
  oidc_hostname = split(":", var.oidc_addr)[0]
  oidc_port     = length(split(":", var.oidc_addr)) > 1 ? split(":", var.oidc_addr)[1] : "443"
  issuer_url = local.oidc_port == "443" ? "https://${local.oidc_hostname}" : "https://${var.oidc_addr}"

  # Create subnet if not provided
  create_subnet = var.subnet_id == null

  # Determine subnet for instance
  instance_subnet_id = local.create_subnet ? aws_subnet.main[0].id : var.subnet_id
}
