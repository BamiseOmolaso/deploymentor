# IAM Roles and Policies for GitHub Actions
# This is managed separately from application infrastructure to avoid
# the chicken-and-egg problem where the role needs permission to update itself.
# Run this bootstrap with admin credentials locally, not through GitHub Actions.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Check if OIDC provider exists, create if not
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = var.tags
}

# Use existing OIDC provider if it exists
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  environments      = ["dev", "staging", "prod"]
}

# IAM Roles for GitHub Actions (one per environment)
resource "aws_iam_role" "github_actions" {
  for_each = toset(local.environments)

  name = "${var.project_name}-github-actions-role-${each.value}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-github-actions-role-${each.value}"
      Environment = each.value
      ManagedBy   = "Terraform-Bootstrap"
    }
  )
}

# Comprehensive policy for GitHub Actions deployment
# Includes ALL permissions needed for current and planned resources
resource "aws_iam_role_policy" "github_actions_deploy" {
  for_each = toset(local.environments)

  name = "${var.project_name}-github-actions-deploy-${each.value}"
  role = aws_iam_role.github_actions[each.value].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda permissions — scope to deploymentor-* functions only
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:DeleteAlias",
          "lambda:ListVersionsByFunction", # Required for versioning and alias management
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deploymentor-*"
      },
      # Lambda alias permissions (for rollback support)
      {
        Effect = "Allow"
        Action = [
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:UpdateAlias",
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deploymentor-*:live"
      },
      # IAM permissions — scope to deploymentor-* roles only (for Lambda execution roles)
      # NOTE: This does NOT include permissions to modify the GitHub Actions role itself
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:PassRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",                     # Required for tagging Lambda execution roles
          "iam:UntagRole",                   # Required for untagging Lambda execution roles
          "iam:ListInstanceProfilesForRole", # Required for role management
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/deploymentor-*-execution-role"
      },
      # Logs — scope to deploymentor log groups only
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy", # Required for removing retention policies
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup", # Required for reading log group tags
          "logs:TagLogGroup",      # Required for tagging log groups
          "logs:UntagLogGroup",    # Required for untagging log groups
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/deploymentor-*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/apigateway/deploymentor-*",
        ]
      },
      # CloudWatch Alarms — scope to deploymentor alarms only
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",      # Required for creating CloudWatch alarms
          "cloudwatch:DeleteAlarms",        # Required for deleting CloudWatch alarms
          "cloudwatch:DescribeAlarms",      # Required for reading alarm configuration
          "cloudwatch:ListTagsForResource", # Required for reading alarm tags
          "cloudwatch:TagResource",         # Required for tagging alarms
          "cloudwatch:UntagResource",       # Required for untagging alarms
        ]
        Resource = "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:deploymentor-*"
      },
      # API Gateway — scope to deploymentor APIs only
      # HTTP API v2 uses REST-style permissions with wildcards
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:DELETE",
          "apigateway:PATCH",
        ]
        Resource = [
          "arn:aws:apigateway:${data.aws_region.current.name}::/apis/*",
          "arn:aws:apigateway:${data.aws_region.current.name}::/apis",
          "arn:aws:apigateway:${data.aws_region.current.name}::/apis/*/stages/*",
          "arn:aws:apigateway:${data.aws_region.current.name}::/apis/*/integrations/*",
          "arn:aws:apigateway:${data.aws_region.current.name}::/apis/*/routes/*",
        ]
      },
      # CloudWatch Metrics — scope to deploymentor metrics only
      # Note: Some CloudWatch actions require Resource = "*" due to service limitations
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
        ]
        Resource = [
          "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:metric/deploymentor-*/*",
          "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:metric/AWS/Lambda/deploymentor-*/*",
        ]
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AWS/Lambda"
          }
        }
      },
      # SSM — scope to deploymentor parameters only
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/deploymentor/*"
      },
      # SNS — scope to deploymentor topics only (for CloudWatch alarms)
      {
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:TagResource",
          "sns:UntagResource", # Required for untagging SNS topics
          "sns:ListTagsForResource",
          "sns:DeleteTopic",
        ]
        Resource = [
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deploymentor-*",
        ]
      },
      # Budgets — scope to deploymentor budgets only
      {
        Effect = "Allow"
        Action = [
          "budgets:ModifyBudget",
          "budgets:ViewBudget",
          "budgets:DeleteBudget",
          "budgets:CreateBudget",
          "budgets:DescribeBudgets", # Required for listing and reading budgets
          "budgets:TagResource",
          "budgets:UntagResource",
          "budgets:ListTagsForResource",
        ]
        Resource = [
          "arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/deploymentor-*",
        ]
      },
      # S3 state — scope to deploymentor state bucket only
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject", # required for use_lockfile to release .tflock files
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::deploymentor-terraform-state",
          "arn:aws:s3:::deploymentor-terraform-state/*",
        ]
      },
      # DynamoDB state lock — scope to deploymentor locks table only
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/deploymentor-terraform-locks"
      },
    ]
  })
}

