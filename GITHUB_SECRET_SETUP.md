# GitHub Secret Setup Instructions

## ✅ Step 1: OIDC Resources Deployed

The GitHub OIDC IAM role has been created. Now you need to add the role ARN to GitHub.

## 📋 Step 2: Get the Role ARN

Run this command to get the role ARN:

```bash
cd terraform
terraform output github_actions_role_arn
```

**Expected Output**:
```
arn:aws:iam::YOUR_ACCOUNT_ID:role/deploymentor-github-actions-role-dev
```

**Note**: Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID.

## 🔐 Step 3: Add Secret to GitHub

### Option A: Via GitHub Web UI (Recommended)

1. **Go to your repository**: https://github.com/BamiseOmolaso/deploymentor
2. **Navigate to Settings**:
   - Click on **Settings** tab (top right)
   - Or go directly to: https://github.com/BamiseOmolaso/deploymentor/settings
3. **Go to Secrets**:
   - Click **Secrets and variables** → **Actions**
   - Or go directly to: https://github.com/BamiseOmolaso/deploymentor/settings/secrets/actions
4. **Add New Secret**:
   - Click **New repository secret**
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: Paste the role ARN from Step 2
   - Click **Add secret**

### Option B: Via GitHub CLI

```bash
# Set the role ARN (get from terraform output or .env file)
ROLE_ARN="arn:aws:iam::YOUR_ACCOUNT_ID:role/deploymentor-github-actions-role-dev"

# Add secret
gh secret set AWS_ROLE_ARN --repo BamiseOmolaso/deploymentor --body "$ROLE_ARN"

# Verify it was added
gh secret list --repo BamiseOmolaso/deploymentor
```

## ✅ Step 4: Verify Secret

After adding the secret, verify it exists:

**Via Web UI**:
- Go to Settings → Secrets and variables → Actions
- You should see `AWS_ROLE_ARN` in the list

**Via GitHub CLI**:
```bash
gh secret list --repo BamiseOmolaso/deploymentor
```

## 🎯 Step 5: Test Deployment

Once the secret is added, test the deployment:

```bash
# Make a small change
echo "# Test OIDC deployment" >> README.md

# Commit and push
git add README.md
git commit -m "Test OIDC deployment"
git push origin main

# Watch the workflow
# Go to: https://github.com/BamiseOmolaso/deploymentor/actions
```

## 🔍 Troubleshooting

### Secret Not Found Error

If the workflow fails with "Secret not found":
- Verify secret name is exactly `AWS_ROLE_ARN` (case-sensitive)
- Check you're adding it to the correct repository
- Ensure you have admin access to the repository

### Access Denied Error

If you get "Access Denied" when assuming the role:
- Verify the role ARN is correct
- Check the trust policy matches your repository (`repo:BamiseOmolaso/deploymentor:*`)
- Verify OIDC provider exists in AWS

### Workflow Doesn't Trigger

If the workflow doesn't run:
- Check workflow file syntax (`.github/workflows/deploy.yml`)
- Verify branch name matches (`main`)
- Check workflow permissions include `id-token: write`

## 📝 Quick Reference

**Role ARN**: Get from `terraform output github_actions_role_arn` or `.env` file

**Secret Name**: `AWS_ROLE_ARN`

**Repository**: Your GitHub repository (e.g., `username/repo`)

**Workflow File**: `.github/workflows/deploy.yml`

**Note**: Never commit actual ARNs or account IDs to git. Use environment variables or Terraform outputs.
