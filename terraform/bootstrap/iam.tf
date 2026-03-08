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
      # Statement 1 — Lambda (function operations)
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:DeleteFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:GetFunctionConcurrency",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deploymentor-*"
      },
      # Statement 2 — Lambda alias
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:GetAlias",
          "lambda:DeleteAlias",
          "lambda:ListAliases",
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deploymentor-*"
      },
      # Statement 3 — CloudWatch Logs
      # DescribeLogGroups requires Resource = "*" — no resource-level support in AWS
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:ListTagsLogGroup",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:CreateLogDelivery",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
        ]
        Resource = "*"
      },
      # Statement 4 — CloudWatch Alarms
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
        ]
        Resource = "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:deploymentor-*"
      },
      # Statement 5 — SNS
      {
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:TagResource",
          "sns:ListTagsForResource",
          "sns:UntagResource",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic",
        ]
        Resource = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deploymentor-*"
      },
      # Statement 6 — IAM (lambda execution role only)
      # NOTE: This does NOT include permissions to modify the GitHub Actions role itself
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:UpdateRoleDescription",
          "iam:UpdateAssumeRolePolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/deploymentor-*"
      },
      # Statement 7 — API Gateway
      # API Gateway uses HTTP verbs — no resource-level ARN filtering
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
          "apigateway:TagResource",
        ]
        Resource = "*"
      },
      # Statement 8 — SSM
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
          "ssm:AddTagsToResource",
          "ssm:ListTagsForResource",
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/deploymentor/*"
      },
      # Statement 9 — S3 (Terraform state)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
        ]
        Resource = [
          "arn:aws:s3:::deploymentor-terraform-state",
          "arn:aws:s3:::deploymentor-terraform-state/*",
        ]
      },
      # Statement 10 — DynamoDB (state lock)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/deploymentor-terraform-locks"
      },
      # Statement 11 — Budgets
      {
        Effect = "Allow"
        Action = [
          "budgets:CreateBudget",
          "budgets:ModifyBudget",
          "budgets:DeleteBudget",
          "budgets:ViewBudget",
          "budgets:DescribeBudgets",
          "budgets:TagResource",
          "budgets:UntagResource",
          "budgets:ListTagsForResource",
        ]
        Resource = "arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/deploymentor-*"
      },
      # Statement 12 — S3 frontend bucket (static site)
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::deploymentor-frontend-*",
          "arn:aws:s3:::deploymentor-frontend-*/*",
        ]
      },
      # Statement 13 — CloudFront (invalidation + distribution management)
      # CloudFront requires Resource = "*" — no region-specific ARN support
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListDistributions",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:TagResource",
          "cloudfront:ListTagsForResource",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
        ]
        Resource = "*"
      },
    ]
  })
}

