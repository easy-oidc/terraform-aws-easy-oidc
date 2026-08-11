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
  description = "Typed Easy OIDC v2 application configuration. The module injects deployment-owned settings."
  type = object({
    signing_algorithm = optional(string)
    jwks_kid          = optional(string)
    access_token_ttl  = optional(string)
    id_token_ttl      = optional(string)
    templates_dir     = optional(string)
    secrets = object({
      signing_key_name    = string
      encryption_key_name = optional(string)
    })
    user_login_connectors = map(object({
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
        refresh = optional(object({
          scopes               = optional(list(string))
          authorization_params = optional(map(string))
        }))
      }))
    }))
    email = optional(object({
      verification_mode = optional(string)
      otp_secret_name   = optional(string)
      otp_ttl           = optional(string)
      smtp = optional(object({
        host               = string
        port               = number
        from_name          = optional(string)
        from_address       = string
        credentials_secret = optional(string)
        tls_mode           = optional(string)
      }))
      turnstile = optional(object({
        site_key    = string
        secret_name = string
      }))
    }))
    service_token_issuers = optional(map(object({
      provider      = string
      issuer_url    = optional(string)
      signing_algs  = optional(list(string))
      max_token_age = optional(string)
    })))
    static_policy = optional(object({
      require_user_groups_from_policy = optional(bool)
      default_redirect_uris           = optional(list(string))
      user_group_mappings             = optional(map(map(list(string))))
      trust_policies = optional(map(object({
        issuer          = string
        subject         = optional(string)
        groups          = optional(list(string))
        required_claims = optional(any)
        claims          = optional(any)
      })))
      clients = optional(map(object({
        redirect_uris                   = optional(list(string))
        user_group_mapping              = optional(string)
        require_user_groups_from_policy = optional(bool)
        dpop = optional(object({
          mode              = optional(string)
          signing_algorithm = optional(string)
        }))
        require_par = optional(bool)
        trust_bindings = optional(list(object({
          id           = string
          trust_policy = string
          subject      = optional(string)
          groups       = optional(list(string))
          claims       = optional(any)
        })))
        refresh_tokens = optional(object({
          enabled              = optional(bool)
          allow_offline_access = optional(bool)
          session_idle_ttl     = optional(string)
          session_absolute_ttl = optional(string)
          offline_idle_ttl     = optional(string)
          offline_absolute_ttl = optional(string)
        }))
      })))
    }))
    state_database = optional(object({
      driver                   = optional(string)
      path                     = optional(string)
      connection_string_secret = optional(string)
      max_connections          = optional(number)
      query_timeout            = optional(string)
      migrations = optional(object({
        connection_string_secret = string
      }))
    }))
    policy_database = optional(object({
      driver                   = string
      connection_string_secret = string
      redirect_uris            = list(string)
      client_defaults = optional(object({
        require_user_groups_from_policy = optional(bool)
        dpop = optional(object({
          mode              = optional(string)
          signing_algorithm = optional(string)
        }))
        require_par = optional(bool)
        refresh_tokens = optional(object({
          enabled              = optional(bool)
          allow_offline_access = optional(bool)
          session_idle_ttl     = optional(string)
          session_absolute_ttl = optional(string)
          offline_idle_ttl     = optional(string)
          offline_absolute_ttl = optional(string)
        }))
      }))
      queries = optional(object({
        client_exists  = optional(string)
        user_access    = optional(string)
        trust_bindings = optional(string)
      }))
      client_lookup_cache = optional(object({
        ttl          = optional(string)
        negative_ttl = optional(string)
        max_entries  = optional(number)
      }))
      policy_build_cache = optional(object({
        max_entries = optional(number)
      }))
      query_timeout   = optional(string)
      max_connections = optional(number)
      max_trust_rows  = optional(number)
      max_groups      = optional(number)
      max_group_bytes = optional(number)
      max_json_bytes  = optional(number)
    }))
  })

  validation {
    condition     = var.easy_oidc_config.signing_algorithm == null ? true : contains(["RS256", "RS384", "RS512", "ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "EdDSA"], var.easy_oidc_config.signing_algorithm)
    error_message = "easy_oidc_config.signing_algorithm must be supported by Easy OIDC."
  }

  validation {
    condition     = trimspace(var.easy_oidc_config.secrets.signing_key_name) != "" && length(var.easy_oidc_config.user_login_connectors) > 0
    error_message = "easy_oidc_config must define a signing key and at least one user login connector."
  }

  validation {
    condition = alltrue([
      for id, connector in var.easy_oidc_config.user_login_connectors :
      can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", id)) &&
      contains(["google", "github", "generic", "email"], connector.type) &&
      trimspace(connector.display_name) != "" &&
      (connector.type == "email" || try(trimspace(connector.credentials_secret) != "", false)) &&
      (connector.type != "generic" || connector.generic != null)
    ])
    error_message = "Each user login connector must have a path-safe ID, supported type, display name, required credentials, and type-specific configuration."
  }

  validation {
    condition     = !contains([for connector in values(var.easy_oidc_config.user_login_connectors) : connector.type], "github") || try(trimspace(var.easy_oidc_config.secrets.encryption_key_name) != "", false)
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

  validation {
    condition     = try(length(var.easy_oidc_config.static_policy.clients) > 0, false) ? true : var.easy_oidc_config.policy_database != null
    error_message = "easy_oidc_config must configure static_policy.clients or policy_database."
  }

  validation {
    condition = var.easy_oidc_config.state_database == null ? true : (
      coalesce(var.easy_oidc_config.state_database.driver, "sqlite") == "sqlite" ? (
        var.easy_oidc_config.state_database.connection_string_secret == null &&
        var.easy_oidc_config.state_database.max_connections == null &&
        var.easy_oidc_config.state_database.query_timeout == null &&
        var.easy_oidc_config.state_database.migrations == null
        ) : coalesce(var.easy_oidc_config.state_database.driver, "") == "postgresql" ? (
        var.easy_oidc_config.state_database.path == null &&
        try(trimspace(var.easy_oidc_config.state_database.connection_string_secret) != "", false)
      ) : false
    )
    error_message = "state_database must contain only SQLite fields or only PostgreSQL fields, and PostgreSQL requires connection_string_secret."
  }

  validation {
    condition = var.easy_oidc_config.policy_database == null ? true : (
      var.easy_oidc_config.policy_database.driver == "postgresql" &&
      trimspace(var.easy_oidc_config.policy_database.connection_string_secret) != "" &&
      length(var.easy_oidc_config.policy_database.redirect_uris) > 0
    )
    error_message = "easy_oidc_config.policy_database requires the postgresql driver, a connection string secret, and at least one redirect URI."
  }

  validation {
    condition = alltrue(concat(
      [for client in values(coalesce(try(var.easy_oidc_config.static_policy.clients, null), {})) :
        client.dpop == null ? true : (
          contains(["disabled", "required"], coalesce(client.dpop.mode, "disabled")) &&
          (client.dpop.signing_algorithm == null ? true : (coalesce(client.dpop.mode, "disabled") == "required" && contains(["ES256", "ES512"], client.dpop.signing_algorithm)))
        )
      ],
      [try(var.easy_oidc_config.policy_database.client_defaults.dpop, null) == null ? true : (
        contains(["disabled", "required"], coalesce(var.easy_oidc_config.policy_database.client_defaults.dpop.mode, "disabled")) &&
        (var.easy_oidc_config.policy_database.client_defaults.dpop.signing_algorithm == null ? true : (coalesce(var.easy_oidc_config.policy_database.client_defaults.dpop.mode, "disabled") == "required" && contains(["ES256", "ES512"], var.easy_oidc_config.policy_database.client_defaults.dpop.signing_algorithm)))
      )]
    ))
    error_message = "DPoP mode must be disabled or required; signing_algorithm requires required mode and must be ES256 or ES512."
  }

  validation {
    condition = alltrue([
      for issuer in values(coalesce(var.easy_oidc_config.service_token_issuers, {})) :
      contains(["github", "buildkite", "oidc"], issuer.provider) && (
        issuer.provider != "oidc" || (try(trimspace(issuer.issuer_url) != "", false) && try(length(issuer.signing_algs) > 0, false) && try(trimspace(issuer.max_token_age) != "", false))
      )
    ])
    error_message = "Service token issuers must use github, buildkite, or oidc; oidc issuers require issuer_url, signing_algs, and max_token_age."
  }

  validation {
    condition = alltrue(concat(
      [for connector in values(var.easy_oidc_config.user_login_connectors) : connector.order == null ? true : floor(connector.order) == connector.order],
      [try(var.easy_oidc_config.email.smtp.port, null) == null ? true : (floor(var.easy_oidc_config.email.smtp.port) == var.easy_oidc_config.email.smtp.port && var.easy_oidc_config.email.smtp.port >= 1 && var.easy_oidc_config.email.smtp.port <= 65535)],
      [try(var.easy_oidc_config.state_database.max_connections, null) == null ? true : (floor(var.easy_oidc_config.state_database.max_connections) == var.easy_oidc_config.state_database.max_connections && var.easy_oidc_config.state_database.max_connections >= 1)],
      [try(var.easy_oidc_config.policy_database.max_connections, null) == null ? true : (floor(var.easy_oidc_config.policy_database.max_connections) == var.easy_oidc_config.policy_database.max_connections && var.easy_oidc_config.policy_database.max_connections >= 1 && var.easy_oidc_config.policy_database.max_connections <= 32)],
      [for value in [
        try(var.easy_oidc_config.policy_database.client_lookup_cache.max_entries, null),
        try(var.easy_oidc_config.policy_database.policy_build_cache.max_entries, null),
      ] : floor(value) == value && value >= 1 && value <= 100000 if value != null],
      [for value in [
        try(var.easy_oidc_config.policy_database.max_trust_rows, null),
        try(var.easy_oidc_config.policy_database.max_groups, null),
      ] : floor(value) == value && value >= 1 && value <= 1000 if value != null],
      [try(var.easy_oidc_config.policy_database.max_group_bytes, null) == null ? true : (floor(var.easy_oidc_config.policy_database.max_group_bytes) == var.easy_oidc_config.policy_database.max_group_bytes && var.easy_oidc_config.policy_database.max_group_bytes >= 1 && var.easy_oidc_config.policy_database.max_group_bytes <= 4096)],
      [try(var.easy_oidc_config.policy_database.max_json_bytes, null) == null ? true : (floor(var.easy_oidc_config.policy_database.max_json_bytes) == var.easy_oidc_config.policy_database.max_json_bytes && var.easy_oidc_config.policy_database.max_json_bytes >= 1024 && var.easy_oidc_config.policy_database.max_json_bytes <= 1048576)]
    ))
    error_message = "Integer configuration fields must use whole numbers within the bounds supported by Easy OIDC."
  }
}

variable "run_db_migrations" {
  description = "Run state database migrations before every Easy OIDC service start. Enabling this grants the instance access to state_database.migrations.connection_string_secret when configured."
  type        = bool
  default     = false
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
  description = "Easy OIDC release to install; must be v2.0.0 or later, or latest"
  type        = string
  default     = "latest"

  validation {
    condition     = var.easy_oidc_version == "latest" || can(regex("^v(?:[2-9]|[1-9][0-9]+)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)$", var.easy_oidc_version))
    error_message = "easy_oidc_version must be latest or a final Easy OIDC release tag of v2.0.0 or later."
  }
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
