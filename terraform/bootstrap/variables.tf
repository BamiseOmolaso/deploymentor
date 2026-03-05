variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name of S3 bucket for Terraform state (must be globally unique)"
  type        = string
  default     = "deploymentor-terraform-state"
}

variable "lock_table_name" {
  description = "Name of DynamoDB table for Terraform state locking"
  type        = string
  default     = "deploymentor-terraform-locks"
}

