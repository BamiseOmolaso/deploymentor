# Dev environment configuration
# This file references the parent modules

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "DeployMentor"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda function
module "lambda" {
  source = "../../modules/lambda"

  function_name                  = "${var.project_name}-${var.environment}"
  handler                        = "lambda_handler.handler"
  runtime                        = "python3.12"
  timeout                        = 60
  reserved_concurrent_executions = -1 # No reserved limit for dev (unreserved)
  layers                         = ["arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:deploymentor-dependencies:2"]

  environment_variables = {
    ENVIRONMENT            = var.environment
    GITHUB_TOKEN_SSM_PARAM = var.github_token_ssm_param
    LOG_LEVEL              = var.log_level
    API_KEY_SSM_PARAM      = "/deploymentor/${var.environment}/api_key"
  }

  tags = {
    Name = "${var.project_name}-lambda-${var.environment}"
  }
}

# API Gateway HTTP API
module "api_gateway" {
  source = "../../modules/api_gateway"

  name                       = "${var.project_name}-${var.environment}"
  lambda_function_arn        = module.lambda.function_arn
  lambda_function_name       = module.lambda.function_name
  lambda_function_invoke_arn = module.lambda.function_invoke_arn

  tags = {
    Name = "${var.project_name}-api-${var.environment}"
  }
}

# GitHub OIDC module (for CI/CD)
module "github_oidc" {
  source = "../../modules/github_oidc"

  project_name         = var.project_name
  environment          = var.environment
  github_repo          = var.github_repo != "" ? var.github_repo : "BamiseOmolaso/deploymentor"
  create_oidc_provider = var.create_oidc_provider

  tags = {
    Name = "${var.project_name}-github-oidc-${var.environment}"
  }
}

# Budget module (for cost monitoring)
module "budget" {
  source = "../../modules/budget"

  project_name          = var.project_name
  environment           = var.environment
  monthly_budget_amount = var.monthly_budget_amount
  budget_alert_email    = var.budget_alert_email

  tags = {
    Name = "${var.project_name}-budget-${var.environment}"
  }
}

