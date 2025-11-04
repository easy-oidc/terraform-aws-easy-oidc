# terraform-aws-easy-oidc

Terraform module for deploying [easy-oidc](https://github.com/easy-oidc/easy-oidc) on AWS.

Provisions a minimal OIDC server designed for use with Kubernetes, with Google/GitHub/Generic federation, and support for static group overrides.

## Features

- **Single EC2 instance** deployment (ARM64, t4g.nano by default)
- **Dual-stack IPv4/IPv6** or IPv6-only support
- **Auto-subnet creation** if no subnet id is specified
- **Caddy reverse proxy** with automatic Let's Encrypt TLS (requires DNS to be configured on hostname)
- **AWS Secrets Manager** for storing signing keys and OAuth credentials
- **Static group mappings** for Kubernetes RBAC

## Prerequisites

Create secrets in AWS Secrets Manager before deploying:

### 1. OAuth Client Credentials

**For Google:**
```bash
aws secretsmanager create-secret \
  --name easy-oidc-connector-secret \
  --secret-string '{
    "client_id": "123456789.apps.googleusercontent.com",
    "client_secret": "GOCSPX-xxxxxxxxxxxxxxxxxxxxx"
  }'
```

**For GitHub:**
```bash
aws secretsmanager create-secret \
  --name easy-oidc-connector-secret \
  --secret-string '{
    "client_id": "Iv1.abc123def456",
    "client_secret": "abc123def456..."
  }'
```

### 2. Signing Key (Ed25519)

```bash
openssl genpkey -algorithm ed25519 | aws secretsmanager create-secret \
  --name easy-oidc-signing-key \
  --secret-string file:///dev/stdin
```

## Usage

```hcl
# Configuration
locals {
  vpc_cidr      = "10.0.0.0/16"
  oidc_hostname = "auth.example.com"
}

# Reference secrets
data "aws_secretsmanager_secret" "connector_secret" {
  name = "easy-oidc-connector-secret"
}
data "aws_secretsmanager_secret" "signing_key" {
  name = "easy-oidc-signing-key"
}

# Create VPC with dual-stack networking
resource "aws_vpc" "main" {
  cidr_block                       = local.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main.id
  }
}

# Deploy easy-oidc
module "easy_oidc" {
  source = "easy-oidc/easy-oidc/aws"

  vpc_id                        = aws_vpc.main.id
  oidc_addr                     = local.oidc_hostname
  connector_type                = "google"
  connector_client_secret_arn   = data.aws_secretsmanager_secret.connector_secret.arn
  signing_key_secret_arn        = data.aws_secretsmanager_secret.signing_key.arn
  default_redirect_uris = ["http://localhost:8000"]
  groups_overrides = {
    prod-groups = {
      "alice@example.com" = ["prod-admins", "devs"]
      "bob@example.com"   = ["prod-readonly"]
    }
  }
  clients = {
    kubelogin-prod = {
      groups_override = "prod-groups"
    }
    kubelogin-dev = {
      # Uses default_redirect_uris and upstream IdP groups
    }
  }
}

# Configure DNS records
data "aws_route53_zone" "main" {
  name = "example.com"
}
resource "aws_route53_record" "oidc_a" {
  count   = module.easy_oidc.instance_public_ipv4 != null ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.oidc_hostname
  type    = "A"
  ttl     = 300
  records = [module.easy_oidc.instance_public_ipv4]
}
resource "aws_route53_record" "oidc_aaaa" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.oidc_hostname
  type    = "AAAA"
  ttl     = 300
  records = [module.easy_oidc.instance_public_ipv6]
}
```

## Kubernetes Integration

### API Server Flags

```bash
--oidc-issuer-url=https://auth.example.com
--oidc-client-id=kubelogin-prod
--oidc-username-claim=email
--oidc-groups-claim=groups
```

### kubeconfig Example

You can auth kubectl using [kubelogin](https://github.com/int128/kubelogin).

Example kubeconfig:

```yaml
users:
  - name: oidc-prod
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1
        command: kubelogin
        args:
          - get-token
          - --oidc-issuer-url=https://auth.example.com
          - --oidc-client-id=kubelogin-prod
          - --oidc-use-pkce
```

or test with:

```bash
kubectl oidc-login setup \
    --oidc-issuer-url=https://auth.example.com \
    --oidc-client-id=kubelogin-prod \
    --oidc-use-pkce
```

## IPv6-Only Deployment

```hcl
module "easy_oidc" {
  source = "easy-oidc/easy-oidc/aws"

  vpc_id = aws_vpc.main.id
  # ... other variables ...
  
  enable_ipv4 = false
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name_prefix | Prefix for resource names | `string` | `"easy-oidc"` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| vpc_id | VPC ID | `string` | - | yes |
| oidc_addr | OIDC server address | `string` | - | yes |
| connector_type | Upstream IdP: `google` or `github` | `string` | - | yes |
| connector_client_secret_arn | Secrets Manager ARN for OAuth credentials | `string` | - | yes |
| clients | Map of OIDC client configurations | `map(object)` | - | yes |
| subnet_id | Subnet ID (auto-created if omitted) | `string` | `null` | no |
| signing_key_secret_arn | Secrets Manager ARN for signing key | `string` | `null` | no |
| default_redirect_uris | Default redirect URIs | `list(string)` | `["http://localhost:8000"]` | no |
| groups_overrides | Group override mappings | `map(map(list(string)))` | `{}` | no |
| enable_ipv4 | Enable IPv4 support | `bool` | `true` | no |
| instance_type | EC2 instance type | `string` | `"t4g.nano"` | no |
| allowed_cidrs_ipv4 | Allowed IPv4 CIDRs | `list(string)` | `["0.0.0.0/0"]` | no |
| allowed_cidrs_ipv6 | Allowed IPv6 CIDRs | `list(string)` | `["::/0"]` | no |
| connector_hosted_domain | Google hosted domain | `string` | `null` | no |
| connector_github_hostname | GitHub hostname for GHE | `string` | `"github.com"` | no |
| easy_oidc_version | easy-oidc version to install | `string` | `"latest"` | no |
| caddy_version | Caddy version | `string` | `"latest"` | no |
| kms_key_id | KMS key ID/ARN for EBS encryption (uses AWS managed key if not specified) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| issuer_url | OIDC issuer URL |
| client_ids | List of configured client IDs |
| instance_id | EC2 instance ID |
| instance_public_ipv4 | Public IPv4 address (null if disabled) |
| instance_public_ipv6 | Public IPv6 address |
| subnet_id | Subnet ID |
| security_group_id | Security group ID |

## Resources Created

- **EC2 Instance**: ARM64 (t4g.nano), Ubuntu 22.04 LTS
- **Subnet** (optional): Auto-created with dual-stack support
- **Security Group**: Allows HTTP/HTTPS from configured CIDRs
- **IAM Role**: Read-only access to Secrets Manager
- **IAM Instance Profile**: Attached to EC2 instance

## Security

- All secrets stored in AWS Secrets Manager (never in Terraform state)
- EC2 IAM role has read-only access to specified secrets
- Caddy provides automatic HTTPS with Let's Encrypt
- PKCE enforcement for all OAuth flows
- SQLite database stored at `/var/lib/easy-oidc` for auth code and state storage

## License

Easy OIDC is licensed under the Apache License, Version 2.0.
Copyright 2025 Nadrama Pty Ltd.
See the [LICENSE](./LICENSE) file for details.
