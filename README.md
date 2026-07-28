<!--
Easy OIDC <https://easy-oidc.dev>
Copyright The Easy OIDC Authors
SPDX-License-Identifier: Apache-2.0
-->

# terraform-aws-easy-oidc

OpenTofu/Terraform module for deploying [Easy OIDC](https://easy-oidc.dev) on AWS. It provisions a single EC2 instance, Caddy TLS proxy, dual-stack networking, and least-privilege access to AWS Systems Manager Parameter Store or AWS Secrets Manager.

## Features

- Single ARM64 or AMD64 EC2 instance (`t4g.nano` by default)
- Dual-stack or IPv6-only networking with stable public addresses
- Optional automatic subnet creation
- Caddy with automatic Let's Encrypt TLS
- Explicit, least-privilege Parameter Store or Secrets Manager access
- Optional customer-managed KMS encryption and SSH access

## Prerequisites

Parameter Store is the default secrets backend. Create encrypted parameters before deploying:

```bash
aws ssm put-parameter \
  --name /easy-oidc/google-credentials \
  --type SecureString \
  --value '{"client_id":"123456789.apps.googleusercontent.com","client_secret":"GOCSPX-xxxxxxxx"}'

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 > signing-key.pem
aws ssm put-parameter \
  --name /easy-oidc/signing-key \
  --type SecureString \
  --value "$(cat signing-key.pem)"
rm signing-key.pem

aws ssm put-parameter \
  --name /easy-oidc/encryption-key \
  --type SecureString \
  --value "$(openssl rand -hex 32)"
```

## Usage

The `easy_oidc_config` value follows the [Easy OIDC application configuration](https://easy-oidc.dev/docs/config/). Omit application settings to use Easy OIDC's own defaults. The module only adds deployment-owned values and always overrides `issuer_url`, `http_listen_addr`, `data_dir`, `secrets.provider`, and `secrets.aws_region`. Application secret fields such as `signing_key_name` and `encryption_key_name` are preserved. The module derives least-privilege IAM resources from every secret reference in this object.

```hcl
module "easy_oidc" {
  source = "easy-oidc/easy-oidc/aws"

  vpc_id    = aws_vpc.main.id
  oidc_addr = "auth.example.com"

  easy_oidc_config = {
    secrets = {
      signing_key_name    = "/easy-oidc/signing-key"
      encryption_key_name = "/easy-oidc/encryption-key"
    }
    connectors = {
      google = {
        type               = "google"
        display_name       = "Google"
        credentials_secret = "/easy-oidc/google-credentials"
      }
    }
    groups_overrides = {
      prod-groups = {
        "alice@example.com" = ["prod-admins", "developers"]
      }
    }
    clients = {
      kubelogin-prod = {
        redirect_uris   = ["http://localhost:8000"]
        groups_override = "prod-groups"
      }
    }
  }
}
```

To use Secrets Manager instead, set `secrets_provider = "aws-secrets-manager"`,
and use Secrets Manager names or full ARNs in `easy_oidc_config`.

Then run:

```bash
tofu init
tofu plan
tofu apply
```

See [`examples/main`](examples/main) for a complete VPC and DNS example.

## Kubernetes integration

Configure the API server with the module's `issuer_url` and one of its `client_ids`:

```text
--oidc-issuer-url=https://auth.example.com
--oidc-client-id=kubelogin-prod
--oidc-username-claim=email
--oidc-groups-claim=groups
```

Easy OIDC requires PKCE. For example, use `kubectl oidc-login setup --oidc-use-pkce`.

## IPv6-only deployment

Set `enable_ipv4 = false` and publish only the module's `public_ipv6` output:

```hcl
module "easy_oidc" {
  source = "easy-oidc/easy-oidc/aws"

  # Required inputs omitted.
  enable_ipv4 = false
}
```

## Variables

This table is the complete module input reference.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `vpc_id` | VPC ID where Easy OIDC is deployed. | `string` | n/a | yes |
| `oidc_addr` | Public OIDC server address, such as `auth.example.com` or `auth.example.com:8443`. | `string` | n/a | yes |
| `easy_oidc_config` | Typed Easy OIDC application configuration object. Put application-owned signing, secret names, connectors, clients, email, groups, and related settings here. Deployment-owned fields are overridden as described above. | `object` | n/a | yes |
| `secrets_provider` | AWS secrets backend: `aws-parameter-store` or `aws-secrets-manager`. | `string` | `"aws-parameter-store"` | no |
| `name_prefix` | Prefix for resource names. | `string` | `"easy-oidc"` | no |
| `tags` | Additional tags applied to all resources. | `map(string)` | `{}` | no |
| `subnet_id` | Existing subnet ID; the module creates a subnet when omitted. | `string` | `null` | no |
| `enable_ipv4` | Enable IPv4 in addition to IPv6. | `bool` | `true` | no |
| `instance_type` | EC2 instance type; its architecture selects the matching Debian 13 image. | `string` | `"t4g.nano"` | no |
| `allowed_cidrs_ipv4` | IPv4 CIDRs allowed to access HTTP/HTTPS; ignored when IPv4 is disabled. | `list(string)` | `["0.0.0.0/0"]` | no |
| `allowed_cidrs_ipv6` | IPv6 CIDRs allowed to access HTTP/HTTPS. | `list(string)` | `["::/0"]` | no |
| `easy_oidc_version` | Easy OIDC version to install (git tag or `latest`). | `string` | `"latest"` | no |
| `caddy_version` | Caddy version to install, or `latest`. | `string` | `"latest"` | no |
| `kms_key_id` | KMS key ID/ARN for EBS encryption; uses the AWS-managed key when omitted. | `string` | `null` | no |
| `ssh_key_name` | Existing EC2 key pair name; SSH is disabled when omitted. | `string` | `null` | no |
| `ssh_allowed_cidrs_ipv4` | IPv4 CIDRs allowed SSH access when `ssh_key_name` is set. | `list(string)` | `[]` | no |
| `ssh_allowed_cidrs_ipv6` | IPv6 CIDRs allowed SSH access when `ssh_key_name` is set. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `issuer_url` | OIDC issuer URL. |
| `client_ids` | Client IDs derived from `easy_oidc_config.clients`. |
| `enable_ipv4` | Whether IPv4 is enabled. |
| `public_ipv4` | Public IPv4 address, or null when disabled. |
| `public_ipv6` | Public IPv6 address. |
| `network_interface_id` | Stable network interface ID. |
| `subnet_id` | Created or supplied subnet ID. |
| `security_group_id` | Security group ID. |
| `instance_arch` | Detected instance architecture. |
| `easy_oidc_version` | Resolved installed Easy OIDC version. |
| `caddy_version` | Resolved installed Caddy version. |

## Security

- Secrets remain in Parameter Store or Secrets Manager; only parameter or secret names are included in the rendered configuration.
- The EC2 role receives only the read actions and resources derived from secret references in `easy_oidc_config`.
- Caddy provides automatic HTTPS, and Easy OIDC requires PKCE for clients.
- OAuth state and authorization codes are stored under `/var/lib/easy-oidc`.

## License

Easy OIDC is licensed under the Apache License, Version 2.0.
Copyright The Easy OIDC Authors.
See the [LICENSE](./LICENSE) file for details.
