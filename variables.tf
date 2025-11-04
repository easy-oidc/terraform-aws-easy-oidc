# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "easy-oidc"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID where easy-oidc will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the instance (auto-created if omitted)"
  type        = string
  default     = null
}

variable "oidc_addr" {
  description = "OIDC server address (e.g., 'auth.example.com' or 'auth.example.com:8443')"
  type        = string
}

variable "connector_type" {
  description = "Upstream connector type: 'google' or 'github'"
  type        = string
  validation {
    condition     = contains(["google", "github"], var.connector_type)
    error_message = "connector_type must be 'google' or 'github'"
  }
}

variable "connector_client_secret_arn" {
  description = "ARN of Secrets Manager secret containing OAuth client credentials (JSON with client_id and client_secret)"
  type        = string
}

variable "signing_key_secret_arn" {
  description = "ARN of Secrets Manager secret containing Ed25519 signing key (PEM format)"
  type        = string
  default     = null
}

variable "default_redirect_uris" {
  description = "Default redirect URIs for OIDC clients"
  type        = list(string)
  default     = ["http://localhost:8000"]
}

variable "groups_overrides" {
  description = "Map of group override keys to email-to-groups mappings"
  type        = map(map(list(string)))
  default     = {}
}

variable "clients" {
  description = "Map of OIDC client configurations (key is client_id)"
  type = map(object({
    redirect_uris   = optional(list(string))
    groups_override = optional(string)
  }))
}

variable "enable_ipv4" {
  description = "Enable IPv4 support (set to false for IPv6-only deployment)"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "ARM64 EC2 instance type"
  type        = string
  default     = "t4g.nano"
}

variable "allowed_cidrs_ipv4" {
  description = "Allowed IPv4 CIDRs for HTTPS access (ignored if enable_ipv4 = false)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_cidrs_ipv6" {
  description = "Allowed IPv6 CIDRs for HTTPS access"
  type        = list(string)
  default     = ["::/0"]
}

variable "connector_hosted_domain" {
  description = "Google hosted domain (hd parameter) - only used with connector_type=google"
  type        = string
  default     = null
}

variable "connector_github_hostname" {
  description = "GitHub hostname for GitHub Enterprise - only used with connector_type=github"
  type        = string
  default     = "github.com"
}

variable "easy_oidc_version" {
  description = "Version of easy-oidc to install (git tag or 'latest')"
  type        = string
  default     = "latest"
}

variable "caddy_version" {
  description = "Version of Caddy to install (or 'latest' to use script default)"
  type        = string
  default     = "latest"
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for EBS volume encryption (uses AWS managed key if not specified)"
  type        = string
  default     = null
}

variable "ssh_key_name" {
  description = "Name of existing AWS key pair for SSH access (leave null to disable SSH)"
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs_ipv4" {
  description = "Allowed IPv4 CIDRs for SSH access (only applies if ssh_key_name is set)"
  type        = list(string)
  default     = []
}

variable "ssh_allowed_cidrs_ipv6" {
  description = "Allowed IPv6 CIDRs for SSH access (only applies if ssh_key_name is set)"
  type        = list(string)
  default     = []
}
