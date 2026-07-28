# Easy OIDC <https://easy-oidc.dev>
# Copyright The Easy OIDC Authors
# SPDX-License-Identifier: Apache-2.0

# Generate config.jsonc
locals {
  # Easy OIDC owns defaults for omitted application settings. The module only
  # injects values owned by this deployment.
  config_jsonc = jsonencode(merge(var.easy_oidc_config, {
    issuer_url       = local.issuer_url
    http_listen_addr = "127.0.0.1:8080"
    data_dir         = "/var/lib/easy-oidc"

    secrets = merge(try(var.easy_oidc_config.secrets, {}), {
      provider   = var.secrets_provider
      aws_region = data.aws_vpc.selected.region
    })
  }))

  caddyfile = <<-EOT
    ${var.oidc_addr} {
      reverse_proxy 127.0.0.1:8080
      log {
        output file /var/log/caddy/access.log
      }
    }
  EOT
}
