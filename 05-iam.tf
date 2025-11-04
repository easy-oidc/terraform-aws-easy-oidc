# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

# IAM role for instance
resource "aws_iam_role" "instance_role" {
  name_prefix = "${var.name_prefix}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-instance-role"
    }
  )
}

# IAM policy for Secrets Manager access
resource "aws_iam_role_policy" "instance_role_secrets_access" {
  name_prefix = "${var.name_prefix}-instance-role-secrets-"
  role        = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = compact([
          var.connector_client_secret_arn,
          var.signing_key_secret_arn
        ])
      }
    ]
  })
}

# Attach IAM instance role to EC2 instance
resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.name_prefix}-"
  role        = aws_iam_role.instance_role.name

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-instance-profile"
    }
  )
}
