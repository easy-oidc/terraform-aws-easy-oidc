mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = {
      cidr_block      = "10.0.0.0/16"
      ipv6_cidr_block = "2001:db8::/56"
      region          = "us-east-1"
    }
  }

  mock_data "aws_ec2_instance_type" {
    defaults = { supported_architectures = ["arm64"] }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }

  mock_resource "aws_network_interface" {
    defaults = { ipv6_addresses = ["2001:db8::10"] }
  }
}

mock_provider "http" {
  mock_data "http" {
    defaults = { response_body = "#!/bin/bash\n" }
  }
}

variables {
  vpc_id            = "vpc-0123456789abcdef0"
  subnet_id         = "subnet-0123456789abcdef0"
  oidc_addr         = "auth.example.com"
  easy_oidc_version = "v2.0.0"
  caddy_version     = "v2.10.0"

  easy_oidc_config = {
    secrets = {
      signing_key_name    = "/easy-oidc/signing"
      encryption_key_name = "/easy-oidc/encryption"
    }
    user_login_connectors = {
      google = {
        type               = "google"
        display_name       = "Google"
        credentials_secret = "/easy-oidc/google"
      }
    }
    static_policy = {
      clients = {
        app = {
          redirect_uris = ["https://app.example/callback"]
        }
      }
    }
  }
}

run "valid_cross_field_configuration" {
  command = plan
}

run "refresh_with_non_email_connector_requires_encryption" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        google = {
          type               = "google"
          display_name       = "Google"
          credentials_secret = "/easy-oidc/google"
        }
      }
      static_policy = {
        clients = {
          app = {
            redirect_uris  = ["https://app.example/callback"]
            refresh_tokens = { enabled = true }
          }
        }
      }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "email_delivery_requires_smtp" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        email = { type = "email", display_name = "Email" }
      }
      email         = { otp_secret_name = "/easy-oidc/otp", otp_ttl = "5m" }
      static_policy = { clients = { app = { redirect_uris = ["https://app.example/callback"] } } }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "static_client_requires_redirects" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        google = { type = "google", display_name = "Google", credentials_secret = "/easy-oidc/google" }
      }
      static_policy = { clients = { app = {} } }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "generic_refresh_cannot_override_owned_parameters" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        upstream = {
          type               = "generic"
          display_name       = "Upstream"
          credentials_secret = "/easy-oidc/upstream"
          generic = {
            authorization_url = "https://idp.example/authorize"
            token_url         = "https://idp.example/token"
            userinfo_url      = "https://idp.example/userinfo"
            refresh           = { authorization_params = { client_id = "override" } }
          }
        }
      }
      static_policy = { clients = { app = { redirect_uris = ["https://app.example/callback"] } } }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "refresh_idle_ttl_cannot_exceed_absolute_ttl" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = {
        signing_key_name    = "/easy-oidc/signing"
        encryption_key_name = "/easy-oidc/encryption"
      }
      user_login_connectors = {
        google = { type = "google", display_name = "Google", credentials_secret = "/easy-oidc/google" }
      }
      static_policy = {
        clients = {
          app = {
            redirect_uris = ["https://app.example/callback"]
            refresh_tokens = {
              enabled              = true
              session_idle_ttl     = "1h30m"
              session_absolute_ttl = "1h"
            }
          }
        }
      }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "preset_service_issuer_fields_cannot_be_overridden" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        google = { type = "google", display_name = "Google", credentials_secret = "/easy-oidc/google" }
      }
      service_token_issuers = {
        actions = { provider = "github", signing_algs = ["RS256"] }
      }
      static_policy = { clients = { app = { redirect_uris = ["https://app.example/callback"] } } }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "policy_database_empty_refresh_uses_disabled_default" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        google = { type = "google", display_name = "Google", credentials_secret = "[REDACTED:secret-value]" }
      }
      policy_database = {
        driver                   = "postgresql"
        connection_string_secret = "/easy-oidc/policy-database"
        redirect_uris            = ["https://app.example/callback"]
        client_defaults          = { refresh_tokens = {} }
      }
    }
  }
}

run "explicit_empty_default_redirects_are_invalid" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        google = { type = "google", display_name = "Google", credentials_secret = "[REDACTED:secret-value]" }
      }
      static_policy = {
        default_redirect_uris = []
        clients = {
          app = { redirect_uris = ["https://app.example/callback"] }
        }
      }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "zero_refresh_duration_is_invalid" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = {
        signing_key_name    = "/easy-oidc/signing"
        encryption_key_name = "/easy-oidc/encryption"
      }
      user_login_connectors = {
        google = { type = "google", display_name = "Google", credentials_secret = "[REDACTED:secret-value]" }
      }
      static_policy = {
        clients = {
          app = {
            redirect_uris = ["https://app.example/callback"]
            refresh_tokens = {
              enabled          = true
              session_idle_ttl = "0s"
            }
          }
        }
      }
    }
  }

  expect_failures = [var.easy_oidc_config]
}

run "equivalent_email_otp_duration_is_valid" {
  command = plan

  variables {
    easy_oidc_config = {
      secrets = { signing_key_name = "/easy-oidc/signing" }
      user_login_connectors = {
        email = { type = "email", display_name = "Email" }
      }
      email = {
        otp_secret_name = "/easy-oidc/otp"
        otp_ttl         = "60s"
        smtp = {
          host         = "smtp.example.com"
          port         = 587
          from_address = "auth@example.com"
        }
      }
      static_policy = { clients = { app = { redirect_uris = ["https://app.example/callback"] } } }
    }
  }
}
