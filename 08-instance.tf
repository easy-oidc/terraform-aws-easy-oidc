# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

# EC2 instance with pre-created ENI for stable IPs
resource "aws_launch_template" "main" {
  name_prefix   = "${var.name_prefix}-"
  image_id      = data.aws_ami.ubuntu_arm64.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  network_interfaces {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  user_data = base64encode(local.userdata)

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      encrypted   = true
      kms_key_id  = var.kms_key_id
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = var.name_prefix
      }
    )
  }
}

resource "aws_instance" "main" {
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  user_data_replace_on_change = true

  lifecycle {
    ignore_changes = [launch_template[0].version]
  }
}
