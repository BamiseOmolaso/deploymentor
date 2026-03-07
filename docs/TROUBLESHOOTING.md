# Troubleshooting Guide - DeployMentor

This document catalogs all errors encountered during the DeployMentor deployment process and their solutions. Use this as a reference when facing similar issues.

---

## Table of Contents

1. [CI/CD Pipeline Errors](#cicd-pipeline-errors)
2. [Terraform Deployment Errors](#terraform-deployment-errors)
3. [API Gateway Errors](#api-gateway-errors)
4. [Lambda Function Errors](#lambda-function-errors)
5. [Workflow Trigger Issues](#workflow-trigger-issues)

---

## CI/CD Pipeline Errors

### Error 1: Black Formatting Check Failed

**Error Message:**
```
would reformat /home/runner/work/deploymentor/deploymentor/src/lambda_handler.py
would reformat /home/runner/work/deploymentor/deploymentor/src/analyzers/workflow_analyzer.py

Oh no! 💥 💔 💥
2 files would be reformatted, 10 files would be left unchanged.
Error: Process completed with exit code 1.
```

**Root Cause:**
- Code files were not formatted according to Black's style guide
- CI workflow runs `black --check` which fails if files need reformatting

**Solution:**
1. Run Black to format the files:
   ```bash
   black src/lambda_handler.py src/analyzers/workflow_analyzer.py
   ```
2. Verify formatting:
   ```bash
   black --check src/ tests/
   ```
3. Commit and push the formatted files

**Prevention:**
- Run `black src/ tests/` before committing
- Add pre-commit hooks to auto-format code
- Use IDE integration for Black formatting

---

### Error 2: Flake8 Linting Errors

**Error Message:**
```
src/analyzers/workflow_analyzer.py:212:13: F841 local variable 'step_name' is assigned to but never used
src/analyzers/workflow_analyzer.py:228:101: E501 line too long (107 > 100 characters)
src/analyzers/workflow_analyzer.py:236:101: E501 line too long (105 > 100 characters)
...
Error: Process completed with exit code 1.
```

**Root Cause:**
- Unused variable `step_name` was assigned but never used
- Multiple lines exceeded the 100-character limit

**Solution:**
1. Remove unused variable:
   ```python
   # Before
   step_name = step.get("name", "Unknown")
   step_analysis = self._analyze_step(step)
   
   # After
   step_analysis = self._analyze_step(step)
   ```
2. Break long lines:
   ```python
   # Before
   logger.warning(f"Job '{job_name}' failed with no steps - may indicate early failure or API limitation")
   
   # After
   logger.warning(
       f"Job '{job_name}' failed with no steps - "
       f"may indicate early failure or API limitation"
   )
   ```

**Prevention:**
- Run `flake8 src/ tests/` before committing
- Configure IDE to show line length warnings
- Use Black for automatic line breaking

---

### Error 3: Terraform Format Check Failed

**Error Message:**
```
terraform/main.tf
terraform/modules/api_gateway/main.tf
terraform/modules/github_oidc/main.tf
terraform/modules/lambda/main.tf
terraform/modules/lambda/variables.tf
Error: Terraform exited with code 3.
```

**Root Cause:**
- Terraform files were not formatted according to `terraform fmt` standards
- CI workflow runs `terraform fmt -check` which fails if files need formatting

**Solution:**
1. Format all Terraform files:
   ```bash
   terraform fmt -recursive terraform/
   ```
2. Verify formatting:
   ```bash
   terraform fmt -check -recursive terraform/
   ```
3. Commit and push the formatted files

**Prevention:**
- Run `terraform fmt -recursive terraform/` before committing
- Use IDE integration for Terraform formatting
- Add pre-commit hooks

---

## Terraform Deployment Errors

### Error 4: ResourceAlreadyExists - CloudWatch Log Groups

**Error Message:**
```
Error: creating CloudWatch Logs Log Group (/aws/apigateway/deploymentor-prod): 
operation error CloudWatch Logs: CreateLogGroup, https response error StatusCode: 400, 
RequestID: ..., ResourceAlreadyExistsException: The specified log group already exists

  with module.api_gateway.aws_cloudwatch_log_group.api,
  on modules/api_gateway/main.tf line 56, in resource "aws_cloudwatch_log_group" "api":
  56: resource "aws_cloudwatch_log_group" "api" {
```

**Root Cause:**
- CloudWatch Log Groups were created manually or in a previous deployment
- Terraform state doesn't know about existing resources
- Terraform tries to create them again, causing conflicts

**Solution:**
1. Created `scripts/terraform-import-existing.sh` script
2. Script checks if resources exist in Terraform state
3. If not in state, imports them before applying:
   ```bash
   terraform import module.api_gateway.aws_cloudwatch_log_group.api /aws/apigateway/deploymentor-prod
   ```
4. Added import step to CI/CD workflow (with `continue-on-error: true`)

**Prevention:**
- Always use Terraform to create resources (not manual creation)
- Use remote state backend (S3) for state persistence
- Run import script before first deployment if resources exist

---

### Error 5: ResourceAlreadyExists - IAM Roles

**Error Message:**
```
Error: creating IAM Role (deploymentor-github-actions-role-prod): 
operation error IAM: CreateRole, https response error StatusCode: 409, 
RequestID: ..., EntityAlreadyExists: Role with name deploymentor-github-actions-role-prod already exists.

  with module.github_oidc.aws_iam_role.github_actions,
  on modules/github_oidc/main.tf line 35, in resource "aws_iam_role" "github_actions":
  35: resource "aws_iam_role" "github_actions" {
```

**Root Cause:**
- IAM roles were created in a previous deployment
- Terraform state was lost or not persisted
- Terraform tries to create roles that already exist

**Solution:**
1. Added IAM role imports to `scripts/terraform-import-existing.sh`:
   ```bash
   terraform import module.lambda.aws_iam_role.lambda deploymentor-prod-execution-role
   terraform import module.github_oidc.aws_iam_role.github_actions deploymentor-github-actions-role-prod
   ```
2. Script checks state before importing
3. Uses `-var="environment=${ENVIRONMENT}"` to prevent prompts

**Prevention:**
- Use remote state backend (S3) for state persistence
- Never delete Terraform state files
- Run import script if state is lost

---

### Error 6: ResourceAlreadyExists - Lambda Function

**Error Message:**
```
Error: creating Lambda Function (deploymentor-prod): 
operation error Lambda: CreateFunction, https response error StatusCode: 409, 
RequestID: ..., ResourceConflictException: The operation cannot be performed at this time. 
An update is in progress for resource: ...
```

**Root Cause:**
- Lambda function was created in a previous deployment
- Terraform state doesn't include the function
- Terraform tries to create it again

**Solution:**
1. Added Lambda function import to `scripts/terraform-import-existing.sh`:
   ```bash
   terraform import module.lambda.aws_lambda_function.this deploymentor-prod
   ```
2. Import happens before Terraform apply in CI/CD workflow

**Prevention:**
- Always use Terraform for resource creation
- Maintain Terraform state properly

---

### Error 7: Terraform Import Step Hanging (12+ minutes)

**Error Message:**
- Workflow step "Import existing resources" ran for 12+ minutes without completing
- No error message, just hung indefinitely

**Root Cause:**
- Import commands were waiting for user input or hanging on errors
- Script used `set -e` which caused early exits
- No proper error handling or timeouts

**Solution:**
1. Removed `set -e` from script (allows graceful error handling)
2. Added proper error handling with `|| true` for non-critical imports
3. Removed problematic import step temporarily
4. Later added back with proper existence checks using AWS CLI

**Prevention:**
- Always test import scripts locally first
- Add timeouts to long-running commands
- Use proper error handling (don't use `set -e` for import scripts)
- Check resource existence before attempting import

---

### Error 8: Terraform Import Prompting for Variables

**Error Message:**
- Terraform import commands were prompting for `var.environment` in CI
- Workflow hung waiting for input

**Root Cause:**
- Import commands didn't include `-var` flag
- Terraform tried to prompt for required variables interactively

**Solution:**
1. Added `-var="environment=${ENVIRONMENT}"` to all terraform import commands:
   ```bash
   terraform import -var="environment=${ENVIRONMENT}" "${resource_address}" "${resource_id}"
   ```
2. Ensured `ENVIRONMENT` is set from script argument at the top

**Prevention:**
- Always pass required variables to terraform commands in CI/CD
- Use `-var` or `-var-file` flags
- Never rely on interactive prompts in automated workflows

---

## API Gateway Errors

### Error 9: API Gateway ID Lookup Returning Multiple IDs

**Error Message:**
```
Error: couldn't find resource
  with module.api_gateway.aws_apigatewayv2_stage.default,
  on modules/api_gateway/main.tf line 33, in resource "aws_apigatewayv2_stage" "default":
  33: resource "aws_apigatewayv2_stage" "default" {
```

**Root Cause:**
- AWS CLI query returned multiple API IDs concatenated together
- Query: `Items[?Name=='deploymentor-prod'].ApiId` returned all matching IDs
- Stage import used concatenated string as API ID, causing failure

**Solution:**
1. Fixed query to get only first match using `| [0]`:
   ```bash
   # Before
   API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId" --output text | head -1)
   
   # After
   API_ID=$(aws apigatewayv2 get-apis \
       --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
       --output text)
   ```
2. Added null/empty/None checks before using API_ID
3. Skip dependent imports if API not found

**Prevention:**
- Always use `| [0]` in JMESPath queries when expecting single result
- Validate query results before using them
- Add null checks for all AWS CLI outputs

---

### Error 10: Stage Import Failing - Stage Doesn't Exist

**Error Message:**
```
Error: couldn't find resource
  with module.api_gateway.aws_apigatewayv2_stage.default,
```

**Root Cause:**
- API Gateway stage `$default` didn't exist yet
- Script tried to import non-existent resource
- Terraform import failed with "couldn't find resource"

**Solution:**
1. Added existence check using AWS CLI before importing:
   ```bash
   STAGE_EXISTS=$(aws apigatewayv2 get-stage \
       --api-id "${API_ID}" \
       --stage-name '$default' \
       --query "StageName" \
       --output text 2>/dev/null || echo "")
   
   if [ -n "${STAGE_EXISTS}" ] && [ "${STAGE_EXISTS}" != "None" ]; then
       import_if_exists "module.api_gateway.aws_apigatewayv2_stage.default" "${API_ID}/\$default" "API Gateway Stage" || true
   else
       echo "⏭️  Skipping: \$default stage does not exist yet for API ${API_ID}"
   fi
   ```
2. Applied same pattern to Integration and Route imports
3. Check existence before attempting any import

**Prevention:**
- Always check resource existence before importing
- Use AWS CLI to verify resources exist
- Print clear messages when skipping imports
- Don't rely on terraform import to fail gracefully

---

### Error 11: Lambda Permission Import Failing

**Error Message:**
```
Error: creating Lambda Permission: ResourceConflictException: 
The statement id (AllowExecutionFromAPIGateway) provided already exists
```

**Root Cause:**
- Lambda permission was created in a previous deployment
- Terraform state didn't include it
- Terraform tried to create it again

**Solution:**
1. Added Lambda permission import to `scripts/terraform-import-existing.sh`:
   ```bash
   LAMBDA_PERMISSION_ID="${FUNCTION_NAME}/AllowExecutionFromAPIGateway"
   import_if_exists "module.api_gateway.aws_lambda_permission.api_gateway" "${LAMBDA_PERMISSION_ID}" "Lambda Permission" || true
   ```
2. Import format: `{function_name}/{statement_id}`

**Prevention:**
- Import all resources before first apply
- Maintain complete Terraform state

---

## Lambda Function Errors

### Error 12: Health Check Returning 404

**Error Message:**
```
curl: (22) The requested URL returned error: 404
Error: Process completed with exit code 1.
```

**Root Cause:**
- API Gateway HTTP API v2 event format differs from REST API
- Path extraction wasn't handling all possible event locations
- Lambda handler couldn't find the `/health` route

**Solution:**
1. Improved path extraction in Lambda handler:
   ```python
   # Check multiple locations for path
   path = (
       event.get("path")
       or http_context.get("path")
       or request_context.get("path")
       or event.get("rawPath")
       or "/"
   )
   ```
2. Added logging to debug path extraction
3. Improved health check in workflow with verbose output and fallback

**Prevention:**
- Test Lambda handler with actual API Gateway events
- Log event structure for debugging
- Handle multiple event format variations

---

## Workflow Trigger Issues

### Error 13: Deployment Workflow Not Running on Push

**Error Message:**
- Workflow didn't trigger when pushing changes
- No workflow run appeared in GitHub Actions

**Root Cause:**
- Workflow only triggered on changes to `src/**`, `terraform/**`, or `.github/workflows/deploy.yml`
- Recent commits changed `scripts/terraform-import-existing.sh`
- Scripts directory wasn't in the trigger paths

**Solution:**
1. Added `scripts/**` to workflow trigger paths:
   ```yaml
   on:
     push:
       branches: [main]
       paths:
         - 'src/**'
         - 'terraform/**'
         - '.github/workflows/deploy.yml'
         - 'scripts/**'  # Added
   ```

**Prevention:**
- Review workflow trigger paths when adding new directories
- Test workflow triggers with small commits
- Document which paths trigger deployments

---

## Security Issues

### Error 14: Hardcoded Secrets in Documentation

**Error Message:**
- Security audit found hardcoded AWS account IDs, API Gateway URLs, and role ARNs in documentation

**Root Cause:**
- Documentation included actual values from deployment
- Values were committed to git repository
- Potential security risk if repository is public

**Solution:**
1. Replaced all hardcoded values with placeholders or Terraform outputs
2. Created `.env.example` template file
3. Updated all documentation to reference environment variables or Terraform outputs
4. Created `SECRETS_AUDIT.md` and `SECURITY_CHECKLIST.md`

**Prevention:**
- Never commit actual secrets or account IDs
- Use `.env.example` for templates
- Reference Terraform outputs in documentation
- Regular security audits

---

## Terraform Deployment Errors (Continued)

### Error 15: Terraform State Lock Conflicts (412 PreconditionFailed)

**Error Message:**
```
Error acquiring the state lock. Another operation may be in progress.
```
or
```
412 PreconditionFailed
```

**Root Cause:**
- Multiple deployment workflows running simultaneously
- Both workflows trying to acquire the same Terraform state lock
- Can happen when:
  - Multiple pushes to the same branch happen quickly
  - A workflow run is retried while another is still running
  - Old workflows weren't properly disabled

**Solution:**
1. **Add concurrency controls** to all deploy workflows:
   ```yaml
   concurrency:
     group: deploy-dev  # (or deploy-staging, deploy-prod)
     cancel-in-progress: false
   ```
   This ensures only one deployment runs at a time per environment.

2. **Clear stuck locks**:
   ```bash
   # Force unlock via Terraform
   cd terraform/environments/dev
   terraform init -reconfigure
   terraform force-unlock -force <LOCK_ID>
   
   # Delete lock file directly from S3
   aws s3 rm s3://deploymentor-terraform-state/deploymentor/dev/terraform.tfstate.tflock
   ```

3. **Disable old workflows**: Ensure old deployment workflows are completely disabled (moved out of `.github/workflows/` or renamed to `.disabled`).

**Prevention:**
- Always add concurrency controls to deployment workflows
- Use `cancel-in-progress: false` to queue runs instead of cancelling them
- Regularly audit workflows to ensure no overlapping triggers
- Test deployments locally before pushing to catch issues early
- Monitor workflow runs to detect simultaneous executions

---

## Best Practices Learned

### 1. Always Test Locally First
- Run `black --check`, `flake8`, `terraform fmt -check` before pushing
- Test import scripts locally with actual AWS resources
- Verify workflow changes with small test commits

### 2. Use Proper Error Handling
- Don't use `set -e` in import scripts (allows graceful failures)
- Check resource existence before importing
- Use `continue-on-error: true` for non-critical workflow steps

### 3. Validate AWS CLI Outputs
- Always check for null/empty/None values
- Use `| [0]` in JMESPath queries for single results
- Filter queries by name or other unique identifiers

### 4. Maintain Terraform State
- Use remote state backend (S3) for persistence
- Never delete state files
- Import existing resources before first apply

### 5. Handle Multiple Event Formats
- API Gateway HTTP API v2 has different event structure
- Check multiple locations for path/method
- Add logging for debugging

### 6. Security First
- Never hardcode secrets or account IDs
- Use environment variables or Terraform outputs
- Regular security audits

---

## Quick Reference Commands

### Fix Formatting Issues
```bash
# Python
black src/ tests/
flake8 src/ tests/ --max-line-length=100 --extend-ignore=E203,W503

# Terraform
terraform fmt -recursive terraform/
terraform fmt -check -recursive terraform/
```

### Import Existing Resources
```bash
cd terraform
../scripts/terraform-import-existing.sh prod
```

### Test Locally Before Pushing
```bash
# Run all CI checks
black --check src/ tests/
flake8 src/ tests/ --max-line-length=100 --extend-ignore=E203,W503
pytest tests/ -v
terraform fmt -check -recursive terraform/
terraform validate
```

### Debug API Gateway Issues
```bash
# Get API ID
aws apigatewayv2 get-apis --query "Items[?Name=='deploymentor-prod'].ApiId | [0]" --output text

# Check if stage exists
aws apigatewayv2 get-stage --api-id <API_ID> --stage-name '$default'

# Check integrations
aws apigatewayv2 get-integrations --api-id <API_ID>
```

---

## Related Documentation

- [API Usage Guide](API_USAGE.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Security Practices](SECURITY.md)
- [Testing Guide](TESTING.md)
- [GitHub OIDC Setup](GITHUB_OIDC_SETUP.md)

---

**Last Updated**: March 7, 2026  
**Total Errors Documented**: 15  
**Status**: All errors resolved ✅

