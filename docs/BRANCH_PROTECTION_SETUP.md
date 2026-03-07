# Branch Protection Setup Guide

This guide shows how to set up branch protection rules for `main`, `staging`, and `prod` branches using the GitHub CLI (`gh`). This ensures code flows in one direction: `main` → `staging` → `prod`.

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Admin access to the repository
- Repository: `BamiseOmolaso/deploymentor` (update for your repo)

## Quick Setup (CLI)

Run these commands to set up all branch protection rules:

### 1. Protect `main` Branch

```bash
gh api repos/BamiseOmolaso/deploymentor/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["CI"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

**What this does:**
- Requires CI workflow to pass before merging
- Enforces protection even for admins
- Requires 1 approving review for PRs
- No branch restrictions (allows all users)

### 2. Protect `staging` Branch

```bash
gh api repos/BamiseOmolaso/deploymentor/branches/staging/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["CI","Deploy Dev"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

**What this does:**
- Requires CI workflow to pass
- Requires Deploy Dev workflow to pass (ensures code was deployed to dev)
- Enforces protection even for admins
- Requires 1 approving review for PRs

### 3. Protect `prod` Branch

```bash
gh api repos/BamiseOmolaso/deploymentor/branches/prod/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["CI","Deploy Staging"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

**What this does:**
- Requires CI workflow to pass
- Requires Deploy Staging workflow to pass (ensures code was deployed to staging)
- Enforces protection even for admins
- Requires 1 approving review for PRs

## Verification

Verify that all branch protection rules were applied correctly:

```bash
# Check main protection
gh api repos/BamiseOmolaso/deploymentor/branches/main/protection \
  --jq '{enforce_admins: .enforce_admins.enabled, required_checks: .required_status_checks.contexts}'

# Check staging protection
gh api repos/BamiseOmolaso/deploymentor/branches/staging/protection \
  --jq '{enforce_admins: .enforce_admins.enabled, required_checks: .required_status_checks.contexts}'

# Check prod protection
gh api repos/BamiseOmolaso/deploymentor/branches/prod/protection \
  --jq '{enforce_admins: .enforce_admins.enabled, required_checks: .required_status_checks.contexts}'
```

Expected output should show:
- `enforce_admins: true` for all branches
- `required_checks` containing the expected workflow contexts

## What These Rules Enforce

### Main Branch
- ✅ All commits must pass CI
- ✅ PRs require at least 1 approval
- ✅ Admins are also subject to these rules
- ✅ Direct pushes are blocked (must use PRs)

### Staging Branch
- ✅ All commits must pass CI
- ✅ Deploy Dev workflow must pass (ensures code was tested in dev)
- ✅ PRs require at least 1 approval
- ✅ Admins are also subject to these rules
- ✅ Direct pushes are blocked (must use PRs)

### Prod Branch
- ✅ All commits must pass CI
- ✅ Deploy Staging workflow must pass (ensures code was tested in staging)
- ✅ PRs require at least 1 approval
- ✅ Admins are also subject to these rules
- ✅ Direct pushes are blocked (must use PRs)

## Code Flow Enforcement

These branch protection rules work together with the deployment workflows to enforce one-direction code flow:

1. **main** → Code is merged to main → Auto-deploys to dev
2. **staging** → Code is merged to staging → Must have passed through main first (ancestry check)
3. **prod** → Code is merged to prod → Must have passed through staging first (ancestry check)

The required status checks ensure that:
- Code in `staging` has been successfully deployed to `dev`
- Code in `prod` has been successfully deployed to `staging`

## Troubleshooting

### Error: "Branch protection rule not found"
- Ensure you have admin access to the repository
- Verify the branch name is correct (case-sensitive)
- Check that the branch exists: `gh api repos/BamiseOmolaso/deploymentor/branches`

### Error: "Required status check not found"
- Ensure the workflow contexts match exactly (case-sensitive)
- Check workflow names in `.github/workflows/`:
  - `CI` workflow must exist
  - `Deploy Dev` workflow must exist
  - `Deploy Staging` workflow must exist

### Error: "User not found" (for reviewers)
- Verify the username is correct
- Ensure the user has access to the repository

## Related Documentation

- [Promotion Guide](PROMOTION_GUIDE.md) - How to promote code through environments
- [GitHub Environment Setup](GITHUB_ENVIRONMENT_SETUP.md) - Setting up GitHub Environments
- [Complete Codebase Explanation](COMPLETE_CODEBASE_EXPLANATION.md) - Full architecture overview

---

**Last Updated**: March 7, 2026  
**Setup Method**: GitHub CLI (`gh`)  
**Status**: Automated setup ✅
