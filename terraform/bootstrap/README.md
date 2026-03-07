# Terraform Backend Bootstrap

This directory contains the Terraform configuration to create the S3 bucket and DynamoDB table needed for remote state storage.

## Why Bootstrap?

Terraform needs a backend to store state. But you can't use a backend that doesn't exist yet! This bootstrap creates the backend infrastructure first.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5.0 installed
- Appropriate AWS permissions (S3, DynamoDB, IAM)

## Steps

### 1. Initialize Terraform

```bash
cd terraform/bootstrap
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

This will create:
- S3 bucket for Terraform state (with versioning and encryption)
- **Note**: Modern Terraform uses `use_lockfile = true` which stores locks in S3, so no DynamoDB table is needed

### 3. Apply

```bash
terraform apply
```

### 4. Get Backend Configuration

```bash
terraform output backend_config
```

This will show you the exact backend configuration to add to `terraform/main.tf`.

### 5. Update Main Terraform Configuration

Copy the backend configuration from the output and add it to `terraform/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "deploymentor-terraform-state"
    key          = "deploymentor/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

**Important**: The GitHub Actions IAM role must have `s3:DeleteObject` permission on the state bucket to release `.tflock` files.

### 6. Migrate State

After updating `terraform/main.tf`, run:

```bash
cd ../  # Back to terraform/
terraform init -migrate-state
```

This will migrate your local state to S3.

## Cost

- **S3**: ~$0.023 per GB/month (first 5GB free)
- **Estimated**: < $0.10/month for state storage (no DynamoDB needed with `use_lockfile`)

## Security

- ✅ State bucket has encryption enabled
- ✅ Public access blocked
- ✅ Versioning enabled (can recover deleted state)
- ✅ `use_lockfile` prevents concurrent modifications (stores `.tflock` files in S3)

## Cleanup

To destroy the backend (⚠️ will delete state!):

```bash
cd terraform/bootstrap
terraform destroy
```

**Warning**: Only do this if you're sure you want to delete all Terraform state!

