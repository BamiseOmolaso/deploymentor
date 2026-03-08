# Lambda function deployment package
# Use pre-built zip file with dependencies
# The zip file should be created using scripts/package-lambda-with-deps.sh
locals {
  # Zip is created at repo root, but we're running from terraform/environments/{env}/
  # path.root points to the environment directory, so go up 3 levels to repo root
  lambda_zip_path = "${path.root}/../../../lambda_function.zip"
}

# Lambda function
resource "aws_lambda_function" "this" {
  filename                       = local.lambda_zip_path
  function_name                  = var.function_name
  role                           = aws_iam_role.lambda.arn
  handler                        = "src.${var.handler}"
  runtime                        = var.runtime
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions
  source_code_hash               = fileexists(local.lambda_zip_path) ? filebase64sha256(local.lambda_zip_path) : null
  layers                         = var.layers # Lambda Layers for dependencies
  publish                        = true       # Enable versioning for rollback support

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}

# Lambda alias pointing to latest version (for rollback support)
resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live alias pointing to latest version"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# SNS Topic for alarm notifications (optional, can be extended later)
resource "aws_sns_topic" "alarms" {
  count = var.enable_alarms ? 1 : 0
  name  = "${var.function_name}-alarms"

  tags = var.tags
}

# CloudWatch Alarm: Lambda Errors
resource "aws_cloudwatch_metric_alarm" "errors" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda function has more than 5 errors in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.function_name
  }

  alarm_actions = [aws_sns_topic.alarms[0].arn]

  tags = var.tags
}

# CloudWatch Alarm: Lambda Duration
resource "aws_cloudwatch_metric_alarm" "duration" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.timeout * 1000 * 0.8 # 80% of timeout in milliseconds
  alarm_description   = "Alert when Lambda function duration exceeds 80% of timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.function_name
  }

  alarm_actions = [aws_sns_topic.alarms[0].arn]

  tags = var.tags
}

# CloudWatch Alarm: Lambda Throttles
resource "aws_cloudwatch_metric_alarm" "throttles" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Lambda function is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.function_name
  }

  alarm_actions = [aws_sns_topic.alarms[0].arn]

  tags = var.tags
}
