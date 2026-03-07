# GitHub Environment Setup Guide

This guide explains how to set up GitHub Environments for the DeployMentor deployment lifecycle. GitHub Environments enable manual approval gates and environment-specific secrets.

## Why GitHub Environments?

GitHub Environments provide:
- **Manual approval gates**: Require explicit approval before deploying to production
- **Environment-specific secrets**: Different AWS role ARNs per environment
- **Deployment protection**: Prevent accidental deployments
- **Deployment history**: Track what was deployed to each environment

## Prerequisites

- Admin access to the GitHub repository
- AWS IAM roles already created for each environment (via Terraform)

## Step-by-Step Setup

### Step 1: Navigate to Environment Settings

1. Go to your repository on GitHub
2. Click **Settings** (top navigation bar)
3. In the left sidebar, click **Environments**

**Direct URL**: `https://github.com/BamiseOmolaso/deploymentor/settings/environments`

### Step 2: Create Development Environment

1. Click **New environment**
2. Name it exactly: `development` (lowercase, no spaces)
3. Click **Configure environment**
4. **Deployment branches**: Select "Selected branches" and add `main`
5. Click **Save protection rules**

**Note**: Development environment doesn't need approval gates (auto-deploys on push to main)

### Step 3: Create Staging Environment

1. Click **New environment** again
2. Name it exactly: `staging` (lowercase, no spaces)
3. Click **Configure environment**
4. **Deployment branches**: Select "Selected branches" and add `main`
5. **Required reviewers**: Add yourself (`BamiseOmolaso`) as a reviewer (optional for staging)
6. Click **Save protection rules**

### Step 4: Create Production Environment (REQUIRED)

1. Click **New environment** again
2. Name it exactly: `production` (lowercase, no spaces)
3. Click **Configure environment**
4. **Deployment branches**: Select "Selected branches" and add `main`
5. **Required reviewers**: 
   - Click **Add reviewer**
   - Add `BamiseOmolaso` (or your GitHub username)
   - This creates the manual approval gate
6. **Wait timer**: (Optional) Set to 5 minutes if you want a delay before deployment
7. Click **Save protection rules**

**⚠️ CRITICAL**: The production environment name must be exactly `production` (lowercase). The workflow file references this exact name.

### Step 5: Add Environment Secrets

For each environment, you need to add the AWS role ARN secret:

1. Click on the environment name (e.g., `production`)
2. Scroll to **Environment secrets**
3. Click **Add secret**
4. Name: `AWS_ROLE_ARN`
5. Value: The ARN of the GitHub Actions IAM role for that environment
   - Get from Terraform: `terraform output -raw github_actions_role_arn` (from the environment directory)
   - Format: `arn:aws:iam::ACCOUNT_ID:role/deploymentor-github-actions-role-{env}`
6. Click **Add secret**

**Repeat for each environment** (development, staging, production) with their respective role ARNs.

## Verification

After setup, verify:

1. **Environments exist**: Go to Settings → Environments, you should see:
   - `development`
   - `staging`
   - `production`

2. **Production has approval**: Click on `production` → Check that "Required reviewers" shows your username

3. **Test the approval gate**: 
   - Trigger a production deployment (via workflow_dispatch or git tag `v*`)
   - The workflow should pause at the "Deploy to Prod" job
   - You should see a "Review deployments" button
   - Click it and approve the deployment

## Troubleshooting

### "Environment 'production' not found"

**Problem**: The workflow references an environment that doesn't exist.

**Solution**: 
1. Go to Settings → Environments
2. Create the environment with the exact name from the workflow file
3. Check the workflow file for the exact environment name (case-sensitive)

### "No reviewers available"

**Problem**: The production environment requires reviewers but none are configured.

**Solution**:
1. Go to Settings → Environments → `production`
2. Add yourself as a required reviewer
3. Save the protection rules

### "AWS_ROLE_ARN secret not found"

**Problem**: The workflow can't find the AWS role ARN secret.

**Solution**:
1. Go to Settings → Environments → [environment name]
2. Add the `AWS_ROLE_ARN` secret with the correct role ARN
3. Get the role ARN from Terraform: `cd terraform/environments/{env} && terraform output -raw github_actions_role_arn`

### Deployment not pausing for approval

**Problem**: Production deployments proceed without manual approval.

**Solution**:
1. Verify the environment name in the workflow matches exactly (case-sensitive)
2. Check that "Required reviewers" is configured in the environment settings
3. Ensure you're logged in as a user with permission to approve deployments

## Manual Setup Required

**⚠️ IMPORTANT**: This setup must be done manually in the GitHub UI. The workflow code alone is not enough. The `environment: production` block in the workflow file will not create the environment automatically.

You must:
1. Create the environments manually
2. Configure protection rules manually
3. Add secrets manually

The workflow code only references the environments you create.

## Next Steps

After setting up environments:

1. **Test dev deployment**: Push to `main` - should auto-deploy to dev
2. **Test staging deployment**: Use workflow_dispatch or create tag `staging-*`
3. **Test prod deployment**: Use workflow_dispatch or create tag `v*` - should pause for approval

## References

- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Environment Protection Rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers)

