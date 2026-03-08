# Terraform Bootstrap

This directory contains the Terraform configuration to bootstrap the infrastructure:
1. **Backend resources**: S3 bucket and DynamoDB table for remote state storage
2. **IAM roles**: GitHub Actions IAM roles and policies for all environments (dev, staging, prod)

## Why Bootstrap?

### Backend Bootstrap
Terraform needs a backend to store state. But you can't use a backend that doesn't exist yet! This bootstrap creates the backend infrastructure first.

### IAM Bootstrap (The Right Pattern)
The GitHub Actions IAM role cannot modify its own permissions. This creates a chicken-and-egg problem: when Terraform adds a new AWS service (SNS, budgets, Lambda aliases), the first apply fails because the permission isn't live yet.

**Solution**: Manage IAM roles separately from application infrastructure. This bootstrap runs **locally with admin credentials**, not through GitHub Actions. Once created, the deploy workflows reference these roles via data sources and never modify them.

## Why Bootstrap?

Terraform needs a backend to store state. But you can't use a backend that doesn't exist yet! This bootstrap creates the backend infrastructure first.

## Prerequisites

- AWS CLI configured with **admin credentials** (needed for IAM)
- Terraform >= 1.5.0 installed
- Appropriate AWS permissions (S3, DynamoDB, IAM, Lambda, API Gateway, CloudWatch, SSM, SNS, Budgets)

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

## IAM Bootstrap Pattern

### Why This Pattern?

**The Problem**: If the GitHub Actions role manages its own IAM resources, you hit a bootstrapping problem:
- Terraform needs permission to create/update SNS topics
- But the role doesn't have that permission yet
- So you manually patch IAM via CLI
- Then Terraform sees drift and tries to reconcile
- This creates an endless cycle of manual patches

**The Solution**: Separate IAM management from application deployment:
- **Bootstrap** (this directory): Creates IAM roles/policies with admin credentials locally
- **Deploy workflows**: Reference IAM roles via data sources, never modify them
- **Result**: No more manual IAM patches, no drift, clean separation of concerns

### What Permissions Are Included?

The bootstrap IAM policy includes permissions for:
- ✅ Lambda (functions, versions, aliases)
- ✅ API Gateway (HTTP APIs)
- ✅ CloudWatch (logs, metrics, alarms)
- ✅ SSM Parameter Store
- ✅ SNS (for CloudWatch alarm notifications)
- ✅ Budgets (cost monitoring)
- ✅ S3 (Terraform state)
- ✅ DynamoDB (Terraform state locks)
- ✅ IAM (for Lambda execution roles only, NOT the GitHub Actions role itself)

### After Bootstrap

Once bootstrap runs successfully:
1. Deploy workflows use `manage_iam = false` in the `github_oidc` module
2. The module uses data sources to reference bootstrap-managed roles
3. Deploy workflows can never modify IAM, eliminating the bootstrapping problem
4. To add new permissions, update `bootstrap/iam.tf` and run bootstrap again locally

## Cleanup

To destroy the bootstrap resources (⚠️ will delete state and IAM roles!):

```bash
cd terraform/bootstrap
terraform destroy
```

**Warning**: 
- This will delete all Terraform state!
- This will delete all GitHub Actions IAM roles!
- Only do this if you're sure you want to start over completely!

