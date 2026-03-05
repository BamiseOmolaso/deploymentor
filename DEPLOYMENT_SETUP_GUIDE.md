# Deployment Setup Guide

This guide provides the exact commands to run in order to set up DeployMentor for the first time.

## Prerequisites Check

```bash
# Check Python version (need 3.12+)
python3 --version

# Check Terraform version (need >= 1.5)
terraform version

# Check AWS CLI is configured
aws sts get-caller-identity
```

## Step-by-Step Commands

### 1. Clone and Setup Environment

```bash
# Clone repository
git clone https://github.com/BamiseOmolaso/deploymentor.git
cd deploymentor

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # macOS/Linux
# OR
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements-dev.txt
```

### 2. Run Tests

```bash
pytest -q
```

**Expected**: All 41 tests pass.

### 3. Bootstrap Terraform Backend

```bash
# Navigate to bootstrap directory
cd terraform/bootstrap

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Create backend resources (S3 bucket + DynamoDB table)
terraform apply
```

**Note**: If bucket name is taken, edit `variables.tf` first.

### 4. Store GitHub Token

```bash
# Replace with your actual GitHub token
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_your_token_here" \
  --type "SecureString" \
  --region us-east-1
```

### 5. Deploy Main Infrastructure

```bash
# Navigate to main terraform directory
cd ../  # Back to terraform/

# Initialize Terraform (migrates state to S3)
terraform init -migrate-state

# Review deployment plan
terraform plan -var="environment=prod"

# Deploy
terraform apply -var="environment=prod"
```

### 6. Get API URL

```bash
terraform output api_url
```

### 7. Test Health Endpoint

```bash
# Replace YOUR_API_URL with output from step 6
curl https://YOUR_API_URL/health
```

**Expected**:
```json
{"status":"healthy","service":"deploymentor","version":"0.1.0"}
```

### 8. View Logs

```bash
aws logs tail "/aws/lambda/deploymentor-prod" --since 10m --follow
```

## Verification Checklist

- [ ] All tests pass (`pytest -q`)
- [ ] Bootstrap resources created (S3 bucket + DynamoDB table)
- [ ] GitHub token stored in SSM
- [ ] Main infrastructure deployed
- [ ] Health endpoint returns 200
- [ ] Logs show sanitized requests (no full events)

## Troubleshooting

If you encounter errors:

1. **State migration issues**: Run `terraform init -migrate-state` again
2. **Bucket name conflicts**: Edit `terraform/bootstrap/variables.tf` with unique name
3. **Missing credentials**: Run `aws configure`
4. **Import errors**: Run `./scripts/terraform-import-existing.sh prod`

See [README.md](README.md) Troubleshooting section for more help.

