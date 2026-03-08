# Dev environment outputs

output "api_gateway_url" {
  description = "API Gateway HTTP API URL"
  value       = module.api_gateway.api_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.lambda.function_arn
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = module.lambda.role_arn
}

output "github_actions_role_arn" {
  description = "GitHub Actions IAM role ARN (managed by bootstrap)"
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-github-actions-role-${var.environment}"
}

