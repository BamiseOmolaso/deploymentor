variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "deploymentor"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create the OIDC provider (set to false if it already exists)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "manage_iam" {
  description = "Whether this module should create IAM resources (false = use data sources to reference bootstrap-managed roles)"
  type        = bool
  default     = true
}

