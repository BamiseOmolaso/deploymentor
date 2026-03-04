output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.this.id
}

output "api_url" {
  description = "API Gateway HTTP API endpoint URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_arn" {
  description = "API Gateway ARN"
  value       = aws_apigatewayv2_api.this.arn
}

