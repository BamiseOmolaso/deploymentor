variable "name" {
  description = "API Gateway name"
  type        = string
}

variable "lambda_function_arn" {
  description = "Lambda function ARN"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "lambda_function_invoke_arn" {
  description = "Lambda function invoke ARN"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "api_key_ssm_param" {
  description = "SSM Parameter Store path for API key (optional, for authentication)"
  type        = string
  default     = ""
}

variable "throttle_burst_limit" {
  description = "Max concurrent requests allowed (burst)"
  type        = number
  default     = 10
}

variable "throttle_rate_limit" {
  description = "Sustained requests per second limit"
  type        = number
  default     = 5
}

