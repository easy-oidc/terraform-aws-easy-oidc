# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}
