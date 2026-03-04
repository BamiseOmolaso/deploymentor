# Lambda execution role
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags

  lifecycle {
    ignore_changes = [name]
  }
}

# Basic Lambda execution policy (CloudWatch Logs)
resource "aws_iam_role_policy" "lambda_basic" {
  name = "${var.function_name}-basic-execution"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# SSM Parameter Store read access (least privilege)
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "${var.function_name}-ssm-read"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/deploymentor/*"
        ]
      }
    ]
  })
}

