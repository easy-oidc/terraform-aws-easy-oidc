# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

# Download userdata script
data "http" "userdata_script" {
  url = "https://raw.githubusercontent.com/easy-oidc/easy-oidc/${var.easy_oidc_version == "latest" ? "main" : var.easy_oidc_version}/deploy/userdata.sh"
}

# Prepend vars into userdata script
locals {
  userdata = <<-EOT
    #!/bin/bash
    EASY_OIDC_VERSION=${var.easy_oidc_version}
    CADDY_VERSION=${var.caddy_version}
    OIDC_HOSTNAME=${local.oidc_hostname}
    EASY_OIDC_CONFIG='${local.config_jsonc}'
    SSH=${var.ssh_key_name != null ? "true" : "false"}
    ${replace(data.http.userdata_script.response_body, "/^#!.*/", "")}
  EOT
}
