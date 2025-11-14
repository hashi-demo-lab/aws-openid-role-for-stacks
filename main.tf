locals {
  jwt_audiences = [
    "aws.workload.identity",
    "terraform-stacks-private-preview",
    "platform.onboarding",
    "finance-team-*",
    "engineering-team-*",
    "sales-team-*",
  ]
  
  organization_subjects = [
    for org in var.organization_names : "organization:${org}:*"
  ]
}

# Terraform Cloud OpenID provider supporting multiple audiences.
resource "aws_iam_openid_connect_provider" "stacks" {
  url = "https://app.terraform.io"

  client_id_list  = local.jwt_audiences
  thumbprint_list = ["9E99A48A9960B14926BB7F3B02E22DA2B0AB7280"]
  
  tags = {
    "Source" = "aws-openid-role-for-stacks"
  }
}

# This role is assumed by Terraform Cloud dynamic credentials, accepting any
# stack that matches the subject string from multiple organizations and audiences.
resource "aws_iam_role" "stacks" {
  name = var.role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Effect" : "Allow",
        "Principal" : {
          "Federated" = aws_iam_openid_connect_provider.stacks.arn,
        },
        "Condition" : {
          "StringEquals" : {
            "app.terraform.io:aud" : local.jwt_audiences,
          },
          "StringLike" : {
            "app.terraform.io:sub" : local.organization_subjects,
          },
        },
      },
    ],
  })

  tags = {
    "Source" = "aws-openid-role-for-stacks"
  }
}

# This policy permits the specified allowed actions, always including the
# mandatory action to get the caller identity.
resource "aws_iam_role_policy" "stacks" {
  name = "stacks"
  role = aws_iam_role.stacks.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : concat(var.allowed_actions, [
          "sts:GetCallerIdentity",
        ]),
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}

# Emit the role ARN, for use in the stack configuration.
output "role_arn" {
  description = "ARN of the IAM role for Terraform Stacks"
  value       = aws_iam_role.stacks.arn
}

output "openid_provider_arn" {
  description = "ARN of the OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.stacks.arn
}

output "supported_audiences" {
  description = "List of supported JWT audiences"
  value       = local.jwt_audiences
}

output "supported_organizations" {
  description = "List of organization subjects that can assume this role"
  value       = local.organization_subjects
}
