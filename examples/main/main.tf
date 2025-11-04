# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  region = "us-east-1"
  vpc_cidr      = "10.0.0.0/16"
  route53_zone  = "example.com"
  oidc_hostname = "auth.example.com"
  default_redirect_uris = ["http://localhost:8000"]
  groups_overrides = {
    prod-groups = {
      "demo@example.com" = ["prod-admins", "devs"]
    }
  }
  clients = {
    kubelogin-prod = {
      groups_override = "prod-groups"
    }
    kubelogin-dev = {}
  }
  # SSH configuration - setting a public key path will enable SSH access, null to disable
  ssh_public_key_path = null  # e.g., "~/.ssh/id_rsa.pub"
  ssh_allowed_cidrs_ipv4 = [] # e.g., ["1.2.3.4/32"]
  ssh_allowed_cidrs_ipv6 = [] # e.g., ["2001:db8::/64"]
}

provider "aws" {
  region = local.region
}

# Reference pre-created secrets
data "aws_secretsmanager_secret" "connector_secret" {
  name = "easy-oidc-connector-secret"
}
data "aws_secretsmanager_secret" "signing_key" {
  name = "easy-oidc-signing-key"
}

# VPC with dual-stack support
resource "aws_vpc" "main" {
  cidr_block                       = local.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true
  tags = {
    Name = "easy-oidc-vpc"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "easy-oidc-igw"
  }
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
  tags = {
    Name = "easy-oidc-rt"
  }
}
resource "aws_route_table_association" "main" {
  subnet_id      = module.easy_oidc.subnet_id
  route_table_id = aws_route_table.main.id
}

# SSH key pair for instance access (enabled if ssh_public_key_path is set)
resource "aws_key_pair" "easy_oidc" {
  count = local.ssh_public_key_path != null ? 1 : 0

  key_name   = "easy-oidc-ssh"
  public_key = file(local.ssh_public_key_path)
}

# Deploy easy-oidc
module "easy_oidc" {
  # source = "easy-oidc/easy-oidc/aws"
  source = "../../"

  vpc_id                      = aws_vpc.main.id
  oidc_addr                   = local.oidc_hostname
  connector_type              = "google"
  connector_client_secret_arn = data.aws_secretsmanager_secret.connector_secret.arn
  signing_key_secret_arn      = data.aws_secretsmanager_secret.signing_key.arn
  default_redirect_uris       = local.default_redirect_uris
  groups_overrides            = local.groups_overrides
  clients                     = local.clients

  # SSH access (enabled if ssh_public_key_path is set)
  ssh_key_name           = local.ssh_public_key_path != null ? aws_key_pair.easy_oidc[0].key_name : null
  ssh_allowed_cidrs_ipv4 = local.ssh_public_key_path != null ? local.ssh_allowed_cidrs_ipv4 : null
  ssh_allowed_cidrs_ipv6 = local.ssh_public_key_path != null ? local.ssh_allowed_cidrs_ipv6 : null
}

# DNS records (required for Caddy LetsEncrypt TLS to work - replace with your Route53 zone)
data "aws_route53_zone" "main" {
  name = local.route53_zone
}

resource "aws_route53_record" "oidc_dns_a" {
  count   = module.easy_oidc.enable_ipv4 ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.oidc_hostname
  type    = "A"
  ttl     = 300
  records = [module.easy_oidc.public_ipv4]
}

resource "aws_route53_record" "oidc_dns_aaaa" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.oidc_hostname
  type    = "AAAA"
  ttl     = 300
  records = [module.easy_oidc.public_ipv6]
}
