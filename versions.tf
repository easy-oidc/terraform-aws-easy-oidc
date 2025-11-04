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
