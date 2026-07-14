<!--
Easy OIDC <https://easy-oidc.dev>
Copyright The Easy OIDC Authors
SPDX-License-Identifier: Apache-2.0
-->

# Main Example

This example demonstrates a complete deployment of easy-oidc with:

- VPC with dual-stack IPv4/IPv6 networking
- Internet Gateway for bidirectional internet access
- Google OAuth connector
- Static group mappings for Kubernetes RBAC
- Multiple OIDC clients

## Prerequisites

Create secrets in AWS Secrets Manager:

```bash
# OAuth credentials
aws secretsmanager create-secret \
  --name easy-oidc-connector-secret \
  --secret-string '{
    "client_id": "123456789.apps.googleusercontent.com",
    "client_secret": "GOCSPX-xxxxxxxxxxxxxxxxxxxxx"
  }'

# PKCS8 PEM private key for the default RS256 algorithm
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 | aws secretsmanager create-secret \
  --name easy-oidc-signing-key \
  --secret-string file:///dev/stdin
```

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Kubernetes Integration

Use the issuer URL and client IDs from outputs to configure your Kubernetes API server and kubeconfig.
