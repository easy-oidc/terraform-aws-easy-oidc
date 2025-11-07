# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

# Fetch latest release tags from GitHub API
data "http" "easy_oidc_latest_release" {
  count = var.easy_oidc_version == "latest" ? 1 : 0
  url   = "https://api.github.com/repos/easy-oidc/easy-oidc/releases/latest"
}

data "http" "caddy_latest_release" {
  count = var.caddy_version == "latest" ? 1 : 0
  url   = "https://api.github.com/repos/caddyserver/caddy/releases/latest"
}

locals {
  # Resolve "latest" to actual version tags
  easy_oidc_version_resolved = var.easy_oidc_version == "latest" ? jsondecode(data.http.easy_oidc_latest_release[0].response_body).tag_name : var.easy_oidc_version
  caddy_version_resolved     = var.caddy_version == "latest" ? jsondecode(data.http.caddy_latest_release[0].response_body).tag_name : var.caddy_version
}

# Download userdata script
data "http" "userdata_script" {
  url = "https://raw.githubusercontent.com/easy-oidc/easy-oidc/${local.easy_oidc_version_resolved}/deploy/userdata.sh"
}

# Download sha512 checksums for easy-oidc
data "http" "easy_oidc_checksums" {
  url = "https://github.com/easy-oidc/easy-oidc/releases/download/${local.easy_oidc_version_resolved}/easy-oidc_${trimprefix(local.easy_oidc_version_resolved, "v")}_checksums.txt"
}

# Download sha512 checksums for Caddy
data "http" "caddy_checksums" {
  url = "https://github.com/caddyserver/caddy/releases/download/${local.caddy_version_resolved}/caddy_${trimprefix(local.caddy_version_resolved, "v")}_checksums.txt"
}

locals {
  # Determine architecture from instance type
  instance_arch = length(regexall("^(t4g|a1|c6g|c7g|m6g|m7g|r6g|r7g)", var.instance_type)) > 0 ? "arm64" : "amd64"

  # Parse easy-oidc sha512 from checksums
  easy_oidc_sha512 = try(
    [for line in split("\n", data.http.easy_oidc_checksums.response_body) :
      split("  ", line)[0] if length(regexall("easy-oidc_.*_linux_${local.instance_arch}\\.tar\\.gz", line)) > 0
    ][0],
    ""
  )

  # Parse Caddy sha512 from checksums
  caddy_sha512 = try(
    [for line in split("\n", data.http.caddy_checksums.response_body) :
      split("  ", line)[0] if length(regexall("caddy_.*_linux_${local.instance_arch}\\.tar\\.gz", line)) > 0
    ][0],
    ""
  )
}

# Prepend vars into userdata script
locals {
  userdata = <<-EOT
    #!/bin/bash
    EASY_OIDC_VERSION=${local.easy_oidc_version_resolved}
    EASY_OIDC_SHA512=${local.easy_oidc_sha512}
    CADDY_VERSION=${local.caddy_version_resolved}
    CADDY_SHA512=${local.caddy_sha512}
    OIDC_HOSTNAME=${local.oidc_hostname}
    EASY_OIDC_CONFIG='${local.config_jsonc}'
    SSH=${var.ssh_key_name != null ? "true" : "false"}
    ${replace(data.http.userdata_script.response_body, "/^#!.*/", "")}
  EOT
}
