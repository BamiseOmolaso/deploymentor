output "role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = var.manage_iam ? aws_iam_role.github_actions[0].arn : data.aws_iam_role.github_actions[0].arn
}

output "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = var.manage_iam ? aws_iam_role.github_actions[0].name : data.aws_iam_role.github_actions[0].name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = local.oidc_provider_arn
}

