# Easy OIDC <https://easy-oidc.dev>
# Copyright The Easy OIDC Authors
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

variable "easy_oidc_config" {
  description = "User-controlled Easy OIDC application configuration. The module injects deployment-owned settings."
  type = object({
    signing_algorithm = optional(string)
    jwks_kid          = optional(string)
    token_ttl_seconds = optional(number)
    require_groups    = optional(bool)
    templates_dir     = optional(string)
    secrets = object({
      signing_key_name    = string
      encryption_key_name = optional(string)
    })
    connectors = map(object({
      type               = string
      display_name       = string
      order              = optional(number)
      credentials_secret = optional(string)
      scopes             = optional(list(string))
      google = optional(object({
        hd = optional(string)
      }))
      github = optional(object({
        hostname = optional(string)
      }))
      generic = optional(object({
        authorization_url    = string
        token_url            = string
        userinfo_url         = string
        email_field          = optional(string)
        email_verified_field = optional(string)
        subject_field        = optional(string)
      }))
    }))
    email = optional(object({
      verification_mode = optional(string)
      otp_secret_name   = optional(string)
      otp_ttl_seconds   = optional(number)
      smtp = optional(object({
        host               = string
        port               = number
        from_name          = optional(string)
        from_address       = string
        credentials_secret = string
        tls_mode           = optional(string)
      }))
      turnstile = optional(object({
        site_key    = string
        secret_name = string
      }))
    }))
    default_redirect_uris = optional(list(string), [])
    groups_overrides      = optional(map(map(list(string))), {})
    clients = map(object({
      redirect_uris   = optional(list(string))
      groups_override = optional(string)
      require_groups  = optional(bool)
    }))
  })

  validation {
    condition     = var.easy_oidc_config.signing_algorithm == null ? true : contains(["RS256", "RS384", "RS512", "ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "EdDSA"], var.easy_oidc_config.signing_algorithm)
    error_message = "easy_oidc_config.signing_algorithm must be supported by Easy OIDC."
  }

  validation {
    condition     = length(var.easy_oidc_config.connectors) > 0 && length(var.easy_oidc_config.clients) > 0
    error_message = "easy_oidc_config must define at least one connector and one client."
  }

  validation {
    condition = alltrue([
      for id, connector in var.easy_oidc_config.connectors :
      can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", id)) &&
      contains(["google", "github", "generic", "email"], connector.type) &&
      connector.display_name != "" &&
      (connector.type == "email" || (connector.credentials_secret != null && connector.credentials_secret != "")) &&
      (connector.type != "generic" || connector.generic != null)
    ])
    error_message = "Each connector must have a path-safe ID, supported type, display name, required credentials, and type-specific configuration."
  }

  validation {
    condition     = !contains([for connector in values(var.easy_oidc_config.connectors) : connector.type], "github") || (var.easy_oidc_config.secrets.encryption_key_name != null && var.easy_oidc_config.secrets.encryption_key_name != "")
    error_message = "easy_oidc_config.secrets.encryption_key_name is required for GitHub connectors."
  }

  validation {
    condition     = try(var.easy_oidc_config.email.verification_mode, null) == null ? true : contains(["disabled", "provider", "strict"], var.easy_oidc_config.email.verification_mode)
    error_message = "easy_oidc_config.email.verification_mode must be disabled, provider, or strict."
  }

  validation {
    condition     = try(var.easy_oidc_config.email.smtp.tls_mode, null) == null ? true : contains(["starttls", "implicit", "plaintext"], var.easy_oidc_config.email.smtp.tls_mode)
    error_message = "easy_oidc_config.email.smtp.tls_mode must be starttls, implicit, or plaintext."
  }
}

variable "secrets_provider" {
  description = "AWS secrets backend used by Easy OIDC"
  type        = string
  default     = "aws-parameter-store"

  validation {
    condition     = contains(["aws-parameter-store", "aws-secrets-manager"], var.secrets_provider)
    error_message = "secrets_provider must be aws-parameter-store or aws-secrets-manager."
  }
}

variable "enable_ipv4" {
  description = "Enable IPv4 support (set to false for IPv6-only deployment)"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type; its architecture selects the matching Debian image and release artifacts"
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
