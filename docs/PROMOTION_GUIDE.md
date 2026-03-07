# Code Promotion Guide

This guide explains how to promote code through the environments: main → staging → prod.

## Code Flow Rules

### ✅ Allowed Flow

```
main → staging → prod
```

Code must flow in this exact order. No skipping environments.

### ❌ Not Allowed

- ❌ Direct push to staging or prod
- ❌ main → prod (skipping staging)
- ❌ Hotfix directly to prod
- ❌ Feature branch → staging or prod (must go through main first)

## Promotion Process

### Dev Environment (Automatic)

**Trigger**: Push to `main` branch

**Process**:
1. Push your changes to `main`
2. CI workflow runs automatically
3. If CI passes, `Deploy Dev` workflow runs automatically
4. Code is deployed to dev environment
5. Smoke tests run automatically

**No manual steps required** - dev deploys automatically after CI passes.

**Example**:
```bash
git checkout main
git add .
git commit -m "feat: add new feature"
git push origin main
# CI runs → Dev deploys automatically
```

### Staging Environment (Manual Merge)

**Trigger**: Merge `main` into `staging` branch

**Process**:
1. Ensure your changes are in `main` and dev is working
2. Checkout staging branch
3. Merge main into staging
4. Push to staging
5. CI runs on staging branch
6. If CI passes, `Deploy Staging` workflow runs
7. Workflow verifies commit exists in main history (ancestry check)
8. Code is deployed to staging environment
9. Smoke tests run automatically

**Example**:
```bash
# Make sure main is up to date
git checkout main
git pull origin main

# Merge main into staging
git checkout staging
git merge main
git push origin staging

# CI runs → Staging deploys (after ancestry check passes)
```

**Ancestry Check**:
The workflow verifies that the commit exists in `main` history. If you try to push code directly to staging that hasn't been in main, the deployment will fail with:
```
❌ This commit has not passed through main. Aborting.
   Code must flow: main → staging → prod
```

### Prod Environment (Manual Merge + Approval)

**Trigger**: Merge `staging` into `prod` branch

**Process**:
1. Ensure your changes are in `staging` and staging is healthy
2. Checkout prod branch
3. Merge staging into prod
4. Push to prod
5. CI runs on prod branch
6. `Deploy Prod` workflow runs with three jobs:
   - **verify-ancestry**: Verifies commit exists in staging history
   - **verify-staging**: Runs smoke tests against staging (ensures staging is healthy)
   - **deploy**: Pauses for manual approval in GitHub UI
7. **Manual approval required**: Click "Review deployments" in GitHub Actions
8. Approve the deployment
9. Code is deployed to prod environment
10. Smoke tests run automatically
11. If smoke tests fail, workflow exits with rollback warning

**Example**:
```bash
# Make sure staging is up to date and healthy
git checkout staging
git pull origin staging

# Merge staging into prod
git checkout prod
git merge staging
git push origin prod

# CI runs → Prod workflow starts
# → Ancestry check passes
# → Staging smoke test passes
# → Workflow pauses for approval
# → Go to GitHub Actions, click "Review deployments"
# → Approve
# → Prod deploys → Smoke tests run
```

**Ancestry Check**:
The workflow verifies that the commit exists in `staging` history. If you try to push code directly to prod that hasn't been in staging, the deployment will fail with:
```
❌ This commit has not passed through staging. Aborting.
   Code must flow: main → staging → prod
```

**Manual Approval Gate**:
The workflow pauses at the "Deploy to Prod" job. You must:
1. Go to GitHub Actions
2. Find the running workflow
3. Click "Review deployments"
4. Review what's about to deploy
5. Click "Approve and deploy" or "Reject"

This creates a "pause and think" moment before production changes.

## Hotfix Process

**Even for hotfixes, follow the full flow:**

1. **Fix on main**:
   ```bash
   git checkout main
   # Make your fix
   git commit -m "fix: critical bug fix"
   git push origin main
   # Dev deploys automatically
   ```

2. **Promote to staging**:
   ```bash
   git checkout staging
   git merge main
   git push origin staging
   # Staging deploys
   ```

3. **Promote to prod**:
   ```bash
   git checkout prod
   git merge staging
   git push origin prod
   # Prod workflow runs → Approval required → Deploys
   ```

**No shortcuts** - even critical fixes must go through the full flow. This ensures:
- Code is tested in dev first
- Code is validated in staging
- You have a chance to review before prod
- Rollback is easier (just revert the merge commit)

## Rollback Process

### Rollback from Prod

If something goes wrong in prod:

1. **Revert the merge commit**:
   ```bash
   git checkout prod
   git log --oneline  # Find the merge commit to revert
   git revert <merge-commit-hash>
   git push origin prod
   # Prod workflow runs → Approval required → Deploys previous version
   ```

2. **Or merge previous staging state**:
   ```bash
   git checkout prod
   git reset --hard origin/staging  # Reset to staging state
   git push --force-with-lease origin prod
   # ⚠️ Only if branch protection allows force push (not recommended)
   ```

3. **Or redeploy previous Lambda version**:
   - Go to AWS Console → Lambda → Versions
   - Find previous working version
   - Update alias to point to previous version

### Rollback from Staging

If something goes wrong in staging:

```bash
git checkout staging
git revert <merge-commit-hash>
git push origin staging
# Staging redeploys with previous version
```

## Workflow Triggers Summary

| Environment | Trigger | Approval Required | Ancestry Check |
|------------|---------|-------------------|----------------|
| **Dev** | Push to `main` (after CI) | No | No (first environment) |
| **Staging** | Push to `staging` branch | No | Yes (must exist in main) |
| **Prod** | Push to `prod` branch or `v*` tag | Yes | Yes (must exist in staging) |

## Common Scenarios

### Scenario 1: New Feature

```bash
# 1. Develop on feature branch
git checkout -b feature/new-feature
# ... make changes ...
git push origin feature/new-feature

# 2. Create PR to main
# ... PR review, CI passes, merge ...

# 3. Dev auto-deploys (automatic)

# 4. Promote to staging
git checkout staging
git merge main
git push origin staging

# 5. Test in staging, then promote to prod
git checkout prod
git merge staging
git push origin prod
# ... approve in GitHub UI ...
```

### Scenario 2: Bug Fix

```bash
# 1. Fix on main
git checkout main
# ... make fix ...
git commit -m "fix: bug description"
git push origin main
# Dev auto-deploys

# 2. Promote to staging
git checkout staging
git merge main
git push origin staging

# 3. Promote to prod
git checkout prod
git merge staging
git push origin prod
# ... approve ...
```

### Scenario 3: Version Release

```bash
# 1. Ensure code is in prod and tested
git checkout prod
git tag v1.0.0
git push origin v1.0.0
# Prod workflow can also trigger on v* tags
```

## Troubleshooting

### "This commit has not passed through main"

**Problem**: You're trying to deploy to staging code that hasn't been in main.

**Solution**: 
```bash
git checkout staging
git merge main
git push origin staging
```

### "This commit has not passed through staging"

**Problem**: You're trying to deploy to prod code that hasn't been in staging.

**Solution**:
```bash
git checkout prod
git merge staging
git push origin prod
```

### "Workflow not triggering"

**Problem**: Workflow doesn't run after push.

**Solution**:
- Check that CI passed (dev requires CI success)
- Check that you're pushing to the correct branch
- Check GitHub Actions tab for workflow status
- Verify branch protection rules aren't blocking the push

### "Can't merge: branch protection"

**Problem**: Branch protection is blocking your merge.

**Solution**:
- Ensure CI passes
- Get required approvals
- Use pull requests (don't push directly)

## Best Practices

1. **Always test in dev first** - Dev auto-deploys, so you'll see issues immediately
2. **Verify staging before prod** - Don't skip staging, even for small changes
3. **Use descriptive commit messages** - Makes rollback easier
4. **Review before approving prod** - The approval gate is there for a reason
5. **Monitor smoke tests** - They catch issues before users see them
6. **Keep branches in sync** - Regularly merge main → staging → prod to avoid large merges

## Summary

The promotion flow is:
- **Dev**: Automatic on push to main (after CI)
- **Staging**: Manual merge main → staging (with ancestry check)
- **Prod**: Manual merge staging → prod + approval (with ancestry check)

Code must flow in one direction: main → staging → prod. No shortcuts, no direct pushes, no skipping environments.

