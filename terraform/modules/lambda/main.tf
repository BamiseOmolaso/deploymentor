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
  filename         = local.lambda_zip_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "src.${var.handler}"
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  layers           = var.layers # Lambda Layers for dependencies

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
