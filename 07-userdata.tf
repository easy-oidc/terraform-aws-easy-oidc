# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

# Download userdata script
data "http" "userdata_script" {
  url = "https://raw.githubusercontent.com/easy-oidc/easy-oidc/${var.easy_oidc_version == "latest" ? "main" : var.easy_oidc_version}/deploy/userdata.sh"
}

# Download sha512 checksums for easy-oidc
data "http" "easy_oidc_checksums" {
  count = var.easy_oidc_version != "latest" ? 1 : 0
  url   = "https://github.com/easy-oidc/easy-oidc/releases/download/${var.easy_oidc_version}/easy-oidc_${trimprefix(var.easy_oidc_version, "v")}_checksums.txt"
}

# Download sha512 checksums for Caddy
data "http" "caddy_checksums" {
  count = var.caddy_version != "latest" ? 1 : 0
  url   = "https://github.com/caddyserver/caddy/releases/download/${var.caddy_version}/caddy_${trimprefix(var.caddy_version, "v")}_checksums.txt"
}

locals {
  # Determine architecture from instance type
  instance_arch = length(regexall("^(t4g|a1|c6g|c7g|m6g|m7g|r6g|r7g)", var.instance_type)) > 0 ? "arm64" : "amd64"

  # Parse easy-oidc sha512 from checksums
  easy_oidc_sha512 = (
    var.easy_oidc_version != "latest" && length(data.http.easy_oidc_checksums) > 0 ?
    try(
      [for line in split("\n", data.http.easy_oidc_checksums[0].response_body) :
        split("  ", line)[0] if length(regexall("easy-oidc_.*_linux_${local.instance_arch}\\.tar\\.gz", line)) > 0
      ][0],
      ""
    ) : ""
  )

  # Parse Caddy sha512 from checksums
  caddy_sha512 = (
    var.caddy_version != "latest" && length(data.http.caddy_checksums) > 0 ?
    try(
      [for line in split("\n", data.http.caddy_checksums[0].response_body) :
        split("  ", line)[0] if length(regexall("caddy_.*_linux_${local.instance_arch}\\.tar\\.gz", line)) > 0
      ][0],
      ""
    ) : ""
  )
}

# Prepend vars into userdata script
locals {
  userdata = <<-EOT
    #!/bin/bash
    EASY_OIDC_VERSION=${var.easy_oidc_version}
    EASY_OIDC_SHA512=${local.easy_oidc_sha512}
    CADDY_VERSION=${var.caddy_version}
    CADDY_SHA512=${local.caddy_sha512}
    OIDC_HOSTNAME=${local.oidc_hostname}
    EASY_OIDC_CONFIG='${local.config_jsonc}'
    SSH=${var.ssh_key_name != null ? "true" : "false"}
    ${replace(data.http.userdata_script.response_body, "/^#!.*/", "")}
  EOT
}
