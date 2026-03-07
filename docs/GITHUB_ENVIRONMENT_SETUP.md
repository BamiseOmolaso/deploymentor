# GitHub Environment Setup Guide

This guide shows how to set up GitHub Environments for `development`, `staging`, and `production` using the GitHub CLI (`gh`). Environments are used for OIDC authentication and manual approval gates.

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Admin access to the repository
- Repository: `BamiseOmolaso/deploymentor` (update for your repo)

## Quick Setup (CLI)

### 1. Create Development Environment

```bash
gh api repos/BamiseOmolaso/deploymentor/environments/development \
  --method PUT \
  --field wait_timer=0
```

**What this does:**
- Creates the `development` environment
- No wait timer (immediate deployment)
- Used by `deploy-dev.yml` workflow for OIDC authentication

### 2. Create Staging Environment

```bash
gh api repos/BamiseOmolaso/deploymentor/environments/staging \
  --method PUT \
  --field wait_timer=0
```

**What this does:**
- Creates the `staging` environment
- No wait timer (immediate deployment)
- Used by `deploy-staging.yml` workflow for OIDC authentication

### 3. Create Production Environment

```bash
gh api repos/BamiseOmolaso/deploymentor/environments/production \
  --method PUT \
  --field wait_timer=0
```

**What this does:**
- Creates the `production` environment
- No wait timer (immediate deployment)
- Used by `deploy-prod.yml` workflow for OIDC authentication

### 4. Add Required Reviewers to Production

First, get your user ID:

```bash
USER_ID=$(gh api users/BamiseOmolaso --jq '.id')
echo "User ID: $USER_ID"
```

Then add yourself (or other users) as required reviewers:

```bash
gh api repos/BamiseOmolaso/deploymentor/environments/production \
  --method PUT \
  --field wait_timer=0 \
  --field reviewers="[{\"type\":\"User\",\"id\":$USER_ID}]"
```

**To add multiple reviewers**, get their user IDs and include them in the array:

```bash
# Get multiple user IDs
USER1_ID=$(gh api users/username1 --jq '.id')
USER2_ID=$(gh api users/username2 --jq '.id')

# Add both as reviewers
gh api repos/BamiseOmolaso/deploymentor/environments/production \
  --method PUT \
  --field wait_timer=0 \
  --field reviewers="[{\"type\":\"User\",\"id\":$USER1_ID},{\"type\":\"User\",\"id\":$USER2_ID}]"
```

## Verification

Verify that all environments were created correctly:

```bash
# Check development environment
gh api repos/BamiseOmolaso/deploymentor/environments/development \
  --jq '{name: .name, wait_timer: .protection_rules[0].wait_timer}'

# Check staging environment
gh api repos/BamiseOmolaso/deploymentor/environments/staging \
  --jq '{name: .name, wait_timer: .protection_rules[0].wait_timer}'

# Check production environment
gh api repos/BamiseOmolaso/deploymentor/environments/production \
  --jq '{name: .name, wait_timer: .protection_rules[0].wait_timer, reviewers: [.protection_rules[] | select(.type == "required_reviewers") | .reviewers[] | .login]}'
```

Expected output:
- All environments should exist
- `wait_timer` should be `0` for all
- Production should show the list of required reviewers

## How Environments Work

### OIDC Authentication

Each environment is referenced in the deployment workflows:

```yaml
environment: development  # For deploy-dev.yml
environment: staging      # For deploy-staging.yml
environment: production   # For deploy-prod.yml
```

The workflow uses the environment's OIDC configuration to authenticate with AWS. The AWS role ARN is stored as a secret in the GitHub environment.

### Manual Approval Gate (Production Only)

The production environment has required reviewers configured. When `deploy-prod.yml` reaches the deployment job, it pauses and waits for approval:

```yaml
environment:
  name: production
  url: ${{ steps.get-url.outputs.api_url }}
```

A reviewer must:
1. Go to the GitHub Actions run
2. Click "Review deployments"
3. Approve the deployment
4. The workflow continues

## Environment Configuration

### Development Environment
- **Name**: `development`
- **Wait Timer**: 0 seconds (immediate)
- **Reviewers**: None (auto-deploys)
- **Used by**: `deploy-dev.yml`
- **Purpose**: Automatic deployment after CI passes

### Staging Environment
- **Name**: `staging`
- **Wait Timer**: 0 seconds (immediate)
- **Reviewers**: None (auto-deploys)
- **Used by**: `deploy-staging.yml`
- **Purpose**: Deployment after code is merged to staging branch

### Production Environment
- **Name**: `production`
- **Wait Timer**: 0 seconds (immediate)
- **Reviewers**: Required (manual approval)
- **Used by**: `deploy-prod.yml`
- **Purpose**: Manual approval gate before production deployment

## Setting Up OIDC Secrets

After creating the environments, you need to add the AWS role ARN as a secret to each environment:

```bash
# For development environment
gh secret set AWS_ROLE_ARN \
  --env development \
  --body "arn:aws:iam::ACCOUNT_ID:role/deploymentor-github-actions-role-dev"

# For staging environment
gh secret set AWS_ROLE_ARN \
  --env staging \
  --body "arn:aws:iam::ACCOUNT_ID:role/deploymentor-github-actions-role-staging"

# For production environment
gh secret set AWS_ROLE_ARN \
  --env production \
  --body "arn:aws:iam::ACCOUNT_ID:role/deploymentor-github-actions-role-prod"
```

**Note**: Replace `ACCOUNT_ID` with your AWS account ID. The role ARNs are output by Terraform after deploying each environment.

## Troubleshooting

### Error: "Environment not found"
- Ensure you have admin access to the repository
- Verify the environment name is correct (case-sensitive)
- Check existing environments: `gh api repos/BamiseOmolaso/deploymentor/environments`

### Error: "User not found" (for reviewers)
- Verify the username is correct
- Ensure the user has access to the repository
- Get user ID first: `gh api users/USERNAME --jq '.id'`

### Error: "Secret not found"
- Secrets must be set per environment
- Use `gh secret set` with `--env` flag
- Verify secret exists: `gh secret list --env production`

### Manual Approval Not Working
- Ensure required reviewers are configured
- Check that the workflow uses `environment: production`
- Verify reviewers have access to the repository
- Reviewers must approve via GitHub Actions UI (not CLI)

## Related Documentation

- [Branch Protection Setup](BRANCH_PROTECTION_SETUP.md) - Setting up branch protection rules
- [Promotion Guide](PROMOTION_GUIDE.md) - How to promote code through environments
- [Complete Codebase Explanation](COMPLETE_CODEBASE_EXPLANATION.md) - Full architecture overview

---

**Last Updated**: March 7, 2026  
**Setup Method**: GitHub CLI (`gh`)  
**Status**: Automated setup ✅
