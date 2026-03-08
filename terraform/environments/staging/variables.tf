variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
  default     = "deploymentor"
}

variable "github_token_ssm_param" {
  description = "SSM Parameter Store path for GitHub token"
  type        = string
  default     = "/deploymentor/github/token"
  sensitive   = true
}

variable "log_level" {
  description = "Logging level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR"
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo' (e.g., 'BamiseOmolaso/deploymentor')"
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Whether to create the OIDC provider (set to false if it already exists in your AWS account)"
  type        = bool
  default     = false
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD (default: $5)"
  type        = string
  default     = "5"
}

variable "budget_alert_email" {
  description = "Email address for budget alerts (optional, leave empty to disable budget)"
  type        = string
  default     = ""
}

