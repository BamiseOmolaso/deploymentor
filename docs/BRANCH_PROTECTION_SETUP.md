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
cat > /tmp/branch_protection_staging.json << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI", "Deploy Dev"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF

gh api repos/BamiseOmolaso/deploymentor/branches/staging/protection \
  --method PUT \
  --input /tmp/branch_protection_staging.json
```

**What this does:**
- Requires CI workflow to pass
- Requires Deploy Dev workflow to pass (ensures code was deployed to dev)
- Enforces protection even for admins
- Requires 1 approving review for PRs

### 3. Protect `prod` Branch

```bash
cat > /tmp/branch_protection_prod.json << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI", "Deploy Staging"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF

gh api repos/BamiseOmolaso/deploymentor/branches/prod/protection \
  --method PUT \
  --input /tmp/branch_protection_prod.json
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


# Branch Protection Setup Guide

This guide explains how to set up branch protection rules in GitHub to enforce the one-direction code flow: main → staging → prod.

## Why Branch Protection?

Branch protection rules prevent:
- Direct pushes to protected branches
- Merges without passing CI
- Skipping environments (e.g., main → prod)
- Accidental deletions
- Force pushes that rewrite history

## Prerequisites

- Admin access to the GitHub repository
- CI workflow must be set up and passing

## Step-by-Step Setup

### Step 1: Navigate to Branch Protection Settings

1. Go to your repository on GitHub
2. Click **Settings** (top navigation bar)
3. In the left sidebar, click **Branches**

**Direct URL**: `https://github.com/BamiseOmolaso/deploymentor/settings/branches`

### Step 2: Protect Main Branch

1. Under **Branch protection rules**, click **Add rule** (or edit existing rule for `main`)
2. **Branch name pattern**: `main`
3. **Protect matching branches** - Enable these settings:

   **Required checks:**
   - ✅ Require a pull request before merging
   - ✅ Require approvals: `1` (or more if you have multiple reviewers)
   - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - ✅ Status checks that must pass:
       - `CI / lint` (Lint & Format Check)
       - `CI / test` (Run Tests)
       - `CI / security` (Security Scan)
       - `CI / terraform-validate` (Terraform Validate)

   **Restrictions:**
   - ✅ Restrict pushes that create files larger than 100 MB
   - ✅ Do not allow bypassing the above settings (even for admins)

4. Click **Create** (or **Save changes**)

**What this does**: 
- All changes to `main` must go through a pull request
- CI must pass before merging
- No direct pushes allowed (even for admins)

### Step 3: Protect Staging Branch

1. Click **Add rule** again
2. **Branch name pattern**: `staging`
3. **Protect matching branches** - Enable these settings:

   **Required checks:**
   - ✅ Require a pull request before merging
   - ✅ Require approvals: `1`
   - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - ✅ Status checks that must pass:
       - `CI / lint`
       - `CI / test`
       - `CI / security`
       - `CI / terraform-validate`
       - `Deploy Staging / deploy` (optional - ensures staging deployment works)

   **Restrictions:**
   - ✅ Do not allow bypassing the above settings

   **Important**: 
   - In the pull request settings, you can optionally restrict merges to only come from `main` branch
   - This enforces that staging can only receive code from main

4. Click **Create**

**What this does**:
- All changes to `staging` must go through a pull request
- CI must pass before merging
- Code should only come from `main` (enforced by workflow ancestry checks)

### Step 4: Protect Prod Branch

1. Click **Add rule** again
2. **Branch name pattern**: `prod`
3. **Protect matching branches** - Enable these settings:

   **Required checks:**
   - ✅ Require a pull request before merging
   - ✅ Require approvals: `1` (or more for critical deployments)
   - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - ✅ Status checks that must pass:
       - `CI / lint`
       - `CI / test`
       - `CI / security`
       - `CI / terraform-validate`
       - `Deploy Staging / deploy` (staging must be healthy)
       - `Deploy Prod / verify-staging` (staging verification must pass)

   **Restrictions:**
   - ✅ Do not allow bypassing the above settings
   - ✅ Restrict who can push to matching branches
     - Only allow: `BamiseOmolaso` (or your username)

   **Important**:
   - In the pull request settings, you can optionally restrict merges to only come from `staging` branch
   - This enforces that prod can only receive code from staging

4. Click **Create**

**What this does**:
- All changes to `prod` must go through a pull request
- CI must pass before merging
- Staging must be healthy before prod can deploy
- Code should only come from `staging` (enforced by workflow ancestry checks)
- Only you can approve prod deployments

## Verification

After setup, verify:

1. **Try to push directly to main**:
   ```bash
   git checkout main
   git commit --allow-empty -m "test"
   git push origin main
   ```
   **Expected**: Should be rejected (if branch protection is working)

2. **Try to push directly to staging**:
   ```bash
   git checkout staging
   git commit --allow-empty -m "test"
   git push origin staging
   ```
   **Expected**: Should be rejected

3. **Try to push directly to prod**:
   ```bash
   git checkout prod
   git commit --allow-empty -m "test"
   git push origin prod
   ```
   **Expected**: Should be rejected

4. **Create a PR to main**:
   - Should require CI to pass
   - Should require approval
   - Should block merge if CI fails

## Troubleshooting

### "Branch is protected, you can't push directly"

**This is expected!** Use pull requests instead:
1. Create a feature branch
2. Push to feature branch
3. Create pull request
4. Get approval and pass CI
5. Merge via GitHub UI

### "Required status check is missing"

**Problem**: A required status check hasn't run yet.

**Solution**: 
- Wait for CI to complete
- Or check if the workflow is configured correctly
- The status check name must match exactly (case-sensitive)

### "Can't merge: branch is out of date"

**Problem**: The target branch has new commits.

**Solution**: 
- Update your branch: `git checkout your-branch && git merge main`
- Or use "Update branch" button in GitHub PR UI

### "Can't bypass branch protection"

**Problem**: You're trying to force push or merge without meeting requirements.

**Solution**: 
- This is working as intended - follow the proper flow
- Use pull requests and get approvals
- Ensure CI passes

## Summary

After setup, your branch protection rules should enforce:

- **main**: PR required, CI must pass, approval required
- **staging**: PR required, CI must pass, should only merge from main
- **prod**: PR required, CI + staging checks must pass, approval required, should only merge from staging

This ensures code flows in one direction: main → staging → prod, with no shortcuts.

## References

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging)

