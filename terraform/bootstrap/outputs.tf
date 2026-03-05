output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  description = "Backend configuration for terraform/main.tf"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    key            = "deploymentor/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = true
  }
}

output "backend_config_instructions" {
  description = "Instructions for configuring backend"
  value       = <<-EOT
    Add this to terraform/main.tf:
    
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "deploymentor/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
      encrypt        = true
    }
  EOT
}

