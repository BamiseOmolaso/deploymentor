# Deployment Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.5.0 installed
3. **AWS CLI** configured
4. **GitHub Repository** with Actions enabled
5. **GitHub Personal Access Token** (for GitHub API access)

## Step 1: Create SSM Parameters (Per Environment)

Store your GitHub token securely for each environment:

```bash
# Dev environment
aws ssm put-parameter \
  --name "/deploymentor/dev/github/token" \
  --value "your-github-token-here" \
  --type "SecureString" \
  --region us-east-1

# Staging environment
aws ssm put-parameter \
  --name "/deploymentor/staging/github/token" \
  --value "your-github-token-here" \
  --type "SecureString" \
  --region us-east-1

# Prod environment
aws ssm put-parameter \
  --name "/deploymentor/prod/github/token" \
  --value "your-github-token-here" \
  --type "SecureString" \
  --region us-east-1
```

**Security Note**: Never commit tokens to git! Each environment has its own SSM parameter.

## Step 2: Configure GitHub OIDC

### Create IAM Role for GitHub Actions

1. Create a trust policy file `github-oidc-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/deploymentor:*"
        }
      }
    }
  ]
}
```

2. Create the IAM role:

```bash
aws iam create-role \
  --role-name GitHubActionsDeployMentorRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json
```

3. Attach deployment policy (create policy with Terraform deploy permissions):

```bash
# Policy will be created by Terraform, or create manually
```

4. Configure GitHub Secret:
   - Go to GitHub repository → Settings → Secrets and variables → Actions
   - Add secret: `AWS_ROLE_ARN` = `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsDeployMentorRole`

### Create OIDC Provider (if not exists)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## Step 3: Configure Terraform Backend

The S3 backend is already configured. Each environment uses a separate state file:

- Dev: `deploymentor/dev/terraform.tfstate`
- Staging: `deploymentor/staging/terraform.tfstate`
- Prod: `deploymentor/prod/terraform.tfstate`

All state files are stored in the same S3 bucket: `deploymentor-terraform-state`

## Step 4: Set Up GitHub Environments

**⚠️ CRITICAL**: This step must be done manually in the GitHub UI. See [GITHUB_ENVIRONMENT_SETUP.md](GITHUB_ENVIRONMENT_SETUP.md) for detailed instructions.

1. Go to repository Settings → Environments
2. Create three environments: `development`, `staging`, `production`
3. Configure `production` with required reviewers (manual approval gate)
4. Add `AWS_ROLE_ARN` secret to each environment

## Step 5: Deploy Infrastructure

### Environment Structure

Each environment has its own Terraform configuration:
- `terraform/environments/dev/` - Dev environment
- `terraform/environments/staging/` - Staging environment
- `terraform/environments/prod/` - Prod environment

### Local Deployment (for testing)

```bash
# Deploy to dev
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Deploy to staging
cd ../staging
terraform init
terraform plan
terraform apply

# Deploy to prod
cd ../prod
terraform init
terraform plan
terraform apply
```

### CI/CD Deployment Lifecycle

The deployment process uses a dev → staging → prod lifecycle:

1. **CI Workflow** (`.github/workflows/ci.yml`):
   - Runs automatically on every push to `main` or `develop`
   - Performs code quality checks (formatting, linting)
   - Runs all 54 unit tests
   - Scans for security issues
   - Validates Terraform configuration

2. **Deploy Dev Workflow** (`.github/workflows/deploy-dev.yml`):
   - **Auto-deploys on every push to `main`** (after CI passes)
   - Deploys to dev environment
   - Runs smoke tests automatically
   - No approval required

3. **Deploy Staging Workflow** (`.github/workflows/deploy-staging.yml`):
   - **Manual trigger** (`workflow_dispatch`) or git tag `staging-*`
   - Deploys to staging environment
   - Runs smoke tests automatically
   - Optional approval (configurable)

4. **Deploy Prod Workflow** (`.github/workflows/deploy-prod.yml`):
   - **Manual trigger** (`workflow_dispatch`) or git tag `v*`
   - **Never triggers on push** - only manual or version tags
   - Three jobs: verify-staging → deploy (with approval) → verify-prod
   - **Requires manual approval** before deploying to production
   - Runs smoke tests after deployment

**Deployment Flow**:
```
Push to main → CI runs → Dev auto-deploys
                                    ↓
                          Test in dev, then manually trigger staging
                                    ↓
                          Test in staging, then manually trigger prod
                                    ↓
                          Manual approval required → Prod deploys
```

**To deploy to dev**: Just push to `main` - it deploys automatically after CI passes.

**To deploy to staging**: 
- Go to Actions → Deploy Staging → Run workflow
- Or create a git tag: `git tag staging-v1.0.0 && git push origin staging-v1.0.0`

**To deploy to prod**:
- Go to Actions → Deploy Prod → Run workflow
- Or create a version tag: `git tag v1.0.0 && git push origin v1.0.0`
- **Workflow will pause for manual approval** - click "Review deployments" and approve

## Step 6: Verify Deployment

### Using Smoke Test Script

The easiest way to verify deployment is using the smoke test script:

```bash
# Test dev environment
./scripts/smoke-test.sh dev

# Test staging environment
./scripts/smoke-test.sh staging

# Test prod environment
./scripts/smoke-test.sh prod
```

The script automatically:
- Gets the API URL from Terraform output
- Tests `/health` endpoint (expects 200)
- Tests `/analyze` endpoint with a known failed run ID
- Verifies error detection is working

### Manual Verification

1. Get API URL for an environment:
```bash
cd terraform/environments/dev
terraform output api_gateway_url
```

2. Test health endpoint:
```bash
curl $(terraform output -raw api_gateway_url)/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "deploymentor",
  "version": "0.1.0"
}
```

## Step 7: Update Lambda Code

After making code changes, CI/CD handles deployment automatically:

- **Dev**: Auto-deploys on push to `main`
- **Staging**: Manual trigger or `staging-*` tag
- **Prod**: Manual trigger or `v*` tag (with approval)

Or deploy manually:

```bash
# Package Lambda
zip -r lambda_function.zip src/

# Update Lambda function (replace {env} with dev/staging/prod)
aws lambda update-function-code \
  --function-name deploymentor-{env} \
  --zip-file fileb://lambda_function.zip
```

## Troubleshooting

### Lambda Function Not Found
- Check function name matches Terraform output
- Verify deployment completed successfully

### SSM Parameter Not Found
- Verify parameter exists for the correct environment:
  - Dev: `aws ssm get-parameter --name "/deploymentor/dev/github/token"`
  - Staging: `aws ssm get-parameter --name "/deploymentor/staging/github/token"`
  - Prod: `aws ssm get-parameter --name "/deploymentor/prod/github/token"`
- Check Lambda IAM role has SSM read permissions

### API Gateway 502 Error
- Check CloudWatch Logs for Lambda errors
- Verify Lambda function is deployed
- Check Lambda timeout settings

### OIDC Authentication Fails
- Verify GitHub OIDC provider exists
- Check IAM role trust policy
- Verify GitHub secret `AWS_ROLE_ARN` is set correctly

## Rollback

To rollback to previous version:

```bash
# Rollback specific environment
cd terraform/environments/{env}
terraform plan
# Review changes
terraform apply
```

Or redeploy previous Lambda version from AWS Console:
- Go to Lambda function → Versions
- Select previous version → Publish as new version
- Update alias to point to previous version

## Cost Monitoring

Monitor costs in AWS Cost Explorer:
- Filter by tag: `Project=DeployMentor`
- Set up billing alerts for budget threshold

