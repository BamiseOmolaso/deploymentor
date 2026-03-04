# GitHub OIDC Setup Guide

This guide explains how to set up GitHub OIDC (OpenID Connect) authentication for automated deployments via GitHub Actions.

## 🎯 Why OIDC?

- ✅ **More Secure**: No long-lived AWS access keys stored in GitHub
- ✅ **Temporary Credentials**: Short-lived tokens (1 hour)
- ✅ **Better Audit Trail**: Can see which workflow ran what in CloudTrail
- ✅ **AWS Best Practice**: Recommended by AWS and GitHub
- ✅ **No Key Rotation**: No need to rotate access keys

## 📋 Prerequisites

1. **AWS Account** with admin access (for initial setup)
2. **GitHub Repository** with Actions enabled
3. **Terraform** >= 1.5.0 installed
4. **AWS CLI** configured

## 🚀 Setup Steps

### Step 1: Create OIDC Provider (One-time per AWS Account)

The OIDC provider allows GitHub Actions to authenticate with AWS. This only needs to be done once per AWS account.

**Option A: Via Terraform** (Recommended)
```bash
cd terraform
terraform apply -var="environment=dev" -var="create_oidc_provider=true" -target=module.github_oidc.aws_iam_openid_connect_provider.github
```

**Option B: Via AWS CLI** (If Terraform fails)
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1
```

**Note**: If you get an error saying the provider already exists, that's fine! It means it's already set up. Set `create_oidc_provider = false` in your `terraform.tfvars`.

### Step 2: Configure Terraform Variables

Update `terraform/terraform.tfvars` (or create it from `terraform.tfvars.example`):

```hcl
environment = "dev"
github_repo = "BamiseOmolaso/deploymentor"  # Replace with your repo
create_oidc_provider = false  # Set to true only if creating provider
```

### Step 3: Deploy GitHub OIDC Resources

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

This creates:
- IAM Role for GitHub Actions
- IAM Policy with deployment permissions
- OIDC Provider (if `create_oidc_provider = true`)

### Step 4: Get the Role ARN

After deployment, get the role ARN:

```bash
terraform output github_actions_role_arn
```

Or via AWS CLI:
```bash
aws iam get-role --role-name deploymentor-github-actions-role-dev \
  --query 'Role.Arn' --output text
```

### Step 5: Configure GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: The ARN from Step 4 (e.g., `arn:aws:iam::123456789012:role/deploymentor-github-actions-role-dev`)

### Step 6: Configure GitHub Environment (Optional but Recommended)

For better security, use GitHub Environments:

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name it `production` (or `dev`, `staging`)
4. Add the `AWS_ROLE_ARN` secret to this environment
5. Update `.github/workflows/deploy.yml` to use the environment:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # This will use the environment's secrets
```

## ✅ Verification

### Test the Setup

1. **Push a commit** to trigger the deployment workflow:
   ```bash
   git add .
   git commit -m "Test OIDC deployment"
   git push origin main
   ```

2. **Check GitHub Actions**:
   - Go to your repo → **Actions** tab
   - Watch the deployment workflow run
   - It should authenticate via OIDC (no access key errors)

3. **Verify in AWS CloudTrail**:
   - Go to AWS Console → CloudTrail
   - Look for `AssumeRoleWithWebIdentity` events
   - You should see the GitHub Actions role assumption

### Expected Workflow Output

The workflow should show:
```
✓ Configure AWS Credentials (OIDC)
✓ Set up Python
✓ Package Lambda function
✓ Terraform Init
✓ Terraform Plan
✓ Terraform Apply
✓ Health Check
```

## 🔒 Security Best Practices

1. **Least Privilege**: The IAM role only has permissions needed for deployment
2. **Repository Scoping**: The trust policy only allows your specific repository
3. **Environment Protection**: Use GitHub Environments for production deployments
4. **Audit Trail**: All role assumptions are logged in CloudTrail

## 🐛 Troubleshooting

### Error: "Access Denied" or "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Causes**:
- OIDC provider not created
- Trust policy doesn't match your repository
- Role ARN incorrect in GitHub secret

**Solutions**:
1. Verify OIDC provider exists:
   ```bash
   aws iam list-open-id-connect-providers
   ```

2. Check trust policy matches your repo:
   ```bash
   aws iam get-role --role-name deploymentor-github-actions-role-dev \
     --query 'Role.AssumeRolePolicyDocument'
   ```
   Should contain: `"repo:YOUR_USERNAME/deploymentor:*"`

3. Verify GitHub secret is correct:
   - Check `AWS_ROLE_ARN` in GitHub Secrets
   - Ensure it matches the role ARN from Terraform output

### Error: "Role not found"

**Solution**:
- Verify the role exists: `aws iam get-role --role-name deploymentor-github-actions-role-dev`
- Check Terraform applied successfully
- Verify the role ARN in GitHub secrets matches

### Error: "Workflow doesn't trigger"

**Solutions**:
1. Check workflow file syntax (`.github/workflows/deploy.yml`)
2. Verify branch names match (`main` branch)
3. Check workflow permissions:
   ```yaml
   permissions:
     id-token: write  # Required for OIDC
     contents: read
   ```

## 📚 Additional Resources

- [AWS OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS Actions Configure Credentials](https://github.com/aws-actions/configure-aws-credentials)

## 🔄 Migration from Access Keys

If you're currently using AWS access keys:

1. **Set up OIDC** (follow steps above)
2. **Update workflow** to use OIDC (already done in `deploy.yml`)
3. **Test deployment** with OIDC
4. **Remove access keys** from GitHub Secrets (optional, but recommended)
5. **Delete IAM user** if no longer needed

The workflow will automatically use OIDC if `AWS_ROLE_ARN` is set, falling back to access keys if needed.

