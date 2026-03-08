# Deploymentor: Build in Public Post Series
# Total posts: 49
# Platform: X / LinkedIn
# Project: https://github.com/BamiseOmolaso/deploymentor

---

## POST 1 — The Problem: Why Do Failed CI Runs Feel Impossible to Debug?

Every time a GitHub Actions workflow fails, I spend 10-15 minutes doing the same thing. Open the failed run. Scroll through logs. Search for "error" or "failed". Try to figure out if it's a timeout, a missing dependency, or a Terraform state lock issue. Copy error messages into Stack Overflow. Hope someone else has seen it.

The logs are there. The error is there. But extracting the root cause feels like archaeology. Is it IAM permissions? Is it a file path issue? Is it a network timeout? The signal is buried in noise.

I wanted something that just told me: "Your workflow failed because Terraform couldn't acquire the state lock. Here's how to fix it." So I built it.

Next post: what I actually built.

---

## POST 2 — The Idea: An AI Agent That Explains Failed GitHub Actions Runs

DeployMentor is a serverless API that takes a workflow run_id and returns root cause analysis plus fix suggestions. That's it. No dashboard, no webhooks, no complexity.

The architecture is simple by design. AWS Lambda for compute. API Gateway for the endpoint. SSM Parameter Store for the GitHub token. Terraform for infrastructure. GitHub Actions with OIDC for CI/CD. No AWS keys in GitHub secrets. Budget target: $5-10/month.

The flow: POST a run_id → fetch logs from GitHub → analyze patterns → return structured analysis. No AI APIs yet. Just pattern matching against common CI/CD failure types. Timeouts, dependency issues, IAM errors, Terraform problems.

I'm building this in public because I want to show the real process. The errors. The debugging. The "why did this work locally but fail in CI?" moments.

Next post: why I chose this specific stack.

---

## POST 3 — The Architecture: Lambda, API Gateway, SSM, Terraform, OIDC — Why Each One

Lambda because it scales to zero. I don't want to pay for idle servers. Python 3.12 because it's what Lambda supports and I know Python.

API Gateway HTTP API because it's cheaper than REST API and I don't need REST features. $1 per million requests vs $3.50. At my scale, that matters.

SSM Parameter Store for the GitHub token because Lambda can't have environment variables with secrets. SSM is free for standard parameters. SecureString encryption is built in.

Terraform because infrastructure as code prevents drift. I can recreate everything from scratch. Version control for infrastructure.

GitHub Actions with OIDC because I refuse to store AWS access keys in GitHub secrets. OIDC lets GitHub assume an IAM role. No keys, no rotation, no leaks.

Next post: how I actually built it.

---

## POST 4 — Building with Cursor: What It Actually Means to Prompt Your Way Through a Project

I didn't write this code. I prompted Cursor to write it. That's the honest truth. I told Cursor: "Build a serverless AI agent that analyzes failed GitHub Actions workflows." Then I iterated.

Cursor scaffolded the project structure. I said "add SSM integration to the GitHub client." Cursor added it. I said "create a WorkflowAnalyzer class." Cursor created it. I said "wire up the Lambda handler." Cursor wired it.

But here's what Cursor didn't do: it didn't wire everything together. It built the pieces. I had to connect them. It didn't catch that the run_id flow wasn't actually called. It didn't notice that error_message was hardcoded to None.

Cursor is a pair programmer, not a replacement. It writes code faster than I can, but I still need to understand what it wrote. I still need to test it. I still need to debug it.

Next post: what actually got built.

---

## POST 5 — What Got Built: The GitHub Client, WorkflowAnalyzer, Lambda Handler

Three main components. GitHubClient fetches workflow data from the GitHub API. It handles token retrieval: explicit parameter first, then GITHUB_TOKEN env var for local dev, then SSM Parameter Store for Lambda. It has methods to get workflow runs, jobs, and logs.

WorkflowAnalyzer takes workflow data and identifies failures. It has pattern matching for 8 error types: timeout, dependency, syntax, permission, network, resource, configuration, terraform. It extracts failed jobs, analyzes steps, determines root cause, generates suggestions.

Lambda handler routes requests. GET /health returns status. POST /analyze accepts either logs directly or owner/repo/run_id. It calls the analyzer and returns JSON.

All three components were built. All three had tests. All tests passed. But they weren't connected. The run_id flow existed in code but wasn't called from the endpoint.

Next post: the CI/CD setup.

---

## POST 6 — The CI/CD Setup: GitHub Actions with OIDC, No AWS Keys Stored Anywhere

I set up GitHub Actions to deploy on push to main. The workflow uses OIDC to assume an IAM role in AWS. No access keys. No secrets to rotate. No keys to leak.

The workflow: checkout code, configure AWS credentials via OIDC, set up Python, package Lambda, set up Terraform, run terraform init, import existing resources, terraform plan, terraform apply, health check.

The IAM role has permissions for Lambda, API Gateway, CloudWatch, SSM, S3, DynamoDB. Least privilege. Scoped to specific resources where possible.

The first deploy attempt failed immediately. Terraform was prompting for variables interactively. GitHub Actions doesn't have a TTY. The workflow hung.

Next post: the first fix.

---

## POST 7 — First Deploy Attempt: Terraform Variable Prompt Blocking CI Interactively

The error wasn't an error. Terraform init was waiting for input. It wanted me to confirm backend migration or provide variable values. GitHub Actions has no TTY. The workflow hung for 12 minutes until timeout.

The fix: add `-input=false` to terraform init. This tells Terraform to never prompt. Fail fast instead of waiting forever.

I also added `-var="environment=prod"` to every terraform command in the workflow. No prompts. No hangs. Just deploy or fail.

This is infrastructure 101, but I missed it. Cursor didn't catch it either. The workflow looked correct. It just didn't account for non-interactive execution.

Next post: the first real error.

---

## POST 8 — 409 Conflict: Lambda Already Exists, Terraform Wants to Create It

My first terraform apply failed with ResourceConflictException. The Lambda function already existed. I'd created it manually to test. Terraform didn't know about it. Terraform wanted to create what already existed.

Classic state drift. I had two options: delete the Lambda and let Terraform create it, or import the existing Lambda into Terraform state. I chose import.

The command: `terraform import module.lambda.aws_lambda_function.this deploymentor-prod`. But it failed. The resource address was wrong. The module path was wrong. I spent an hour figuring out the correct address.

I wrote a script to automate imports. But the script kept failing. Some resources didn't exist. Some had different names. Some needed variables.

Next post: the import script.

---

## POST 9 — 409 Again: Lambda Permission Already Exists (Same Class of Problem, Different Resource)

After importing the Lambda, terraform apply failed again. 409 Conflict on the Lambda permission. The permission that allows API Gateway to invoke Lambda already existed. Terraform wanted to create it again.

Same problem, different resource. I added the permission to the import script. Then CloudWatch Log Groups. Then IAM Roles. Then API Gateway stages. Each resource type had the same issue: exists in AWS, missing from Terraform state.

I realized I needed a systematic approach. Check if resource exists in state. If not, try to import it. If import fails, log it and continue. Make the script idempotent.

The script grew to 100+ lines. It handled Lambda functions, permissions, log groups, IAM roles, API Gateway APIs, integrations, routes, stages. All with existence checks and error handling.

Next post: when the script broke.

---

## POST 10 — Building the Import Script: Making Pre-Apply Imports Idempotent

The import script had to be idempotent. Run it multiple times without breaking. Check state before importing. Skip if already imported. Handle missing resources gracefully.

I wrapped every import in a function: `import_if_exists()`. It checks terraform state show first. If the resource is in state, skip. If not, try to import. If import fails, log and continue.

The script also needed to pass variables. Terraform import was prompting for `var.environment`. I added `-var="environment=${ENVIRONMENT}"` to every import command. No prompts. No hangs.

But the script still failed in CI. Some resources didn't exist yet. API Gateway stages are created after the API. I was trying to import stages before the API existed.

Next post: the API Gateway lookup bug.

---

## POST 11 — Multiple API Gateway IDs in One String: How a Bad Query Broke Everything

The import script looked up the API Gateway ID using AWS CLI. The query was supposed to return one ID. It returned multiple IDs concatenated into one string.

The command: `aws apigatewayv2 get-apis --query "Items[].ApiId" --output text`. If multiple APIs existed, it returned "id1 id2 id3" as a single string. The script used this string as the API ID. Everything broke.

The fix: filter by name first, then get the first match. `--query "Items[?Name=='deploymentor-prod'].ApiId | [0]"`. This returns exactly one ID or null.

I also added null checks. If API_ID is empty or "None", skip API Gateway dependent imports. Don't try to import integrations, routes, or stages if the API doesn't exist.

This is why defensive programming matters. AWS CLI can return unexpected formats. Always validate before using.

Next post: the stage that didn't exist.

---

## POST 12 — The $default Stage That Didn't Exist Yet: Checking AWS Before Importing

After fixing the API ID lookup, the script tried to import the API Gateway stage. It failed. The stage didn't exist yet. API Gateway creates the $default stage automatically, but only after the API is fully configured.

I added existence checks using AWS CLI. Before importing the stage, check if it exists: `aws apigatewayv2 get-stage --api-id ${API_ID} --stage-name '$default'`. If it returns 404, skip the import.

Same for integrations and routes. Check if they exist before trying to import. Don't assume resources exist just because the API exists.

The script now handles three states: resource exists in state (skip), resource exists in AWS but not state (import), resource doesn't exist (skip). This makes it safe to run at any point in the deployment lifecycle.

Next post: the Terraform version mismatch.

---

## POST 13 — Terraform Version Mismatch: State File Written by a Newer Version

CI failed with "unsupported checkable object kind 'var'". This error means the Terraform state file was written by a newer version than what's running in CI.

I wrote the state file locally with Terraform 1.14.6. CI was using Terraform 1.5.0 (the default from hashicorp/setup-terraform). The state file format changed between versions. CI couldn't read it.

The fix: pin the Terraform version in GitHub Actions to match local. Updated the workflow to use `terraform_version: '1.14.6'`. Now local and CI use the same version. No more version mismatches.

This is why version pinning matters. Terraform state files are version-specific. Always pin versions in CI to match local development. Don't assume the default version will work.

Next post: the state lock problem.

---

## POST 14 — DynamoDB State Lock: AccessDenied on PutItem

After fixing the version mismatch, CI failed on terraform plan. ConditionalCheckFailedException. Terraform couldn't acquire the state lock. The GitHub Actions IAM role didn't have DynamoDB permissions.

I'd set up S3 backend with DynamoDB locking. The S3 bucket stores state. The DynamoDB table provides locking. But the IAM role only had S3 permissions. No DynamoDB permissions.

Terraform needs three DynamoDB actions for state locking: GetItem (check lock), PutItem (acquire lock), DeleteItem (release lock). The role had none of them.

I added the permissions to the Terraform IAM policy. But I couldn't apply the change. Terraform itself needed those permissions to run. Chicken and egg.

Next post: the bootstrapping problem.

---

## POST 15 — The Bootstrapping Problem: Can't Run Terraform to Fix IAM When IAM Is Broken

I couldn't add DynamoDB permissions via Terraform because Terraform needed those permissions to run. The role was broken, and I couldn't fix it with the broken role.

I had two options: use my personal AWS credentials to patch the role directly, or manually add permissions in the AWS console. I chose option one.

I wrote a script that uses AWS CLI to attach an inline policy directly to the IAM role. The script adds GetItem, PutItem, DeleteItem permissions for the state lock table. Then I updated the Terraform code to match, so future applies keep it in sync.

This is the reality of infrastructure work. Sometimes you need to break the "only Terraform" rule to unblock yourself. Then bring Terraform back in sync. The script ran. CI passed. Terraform could acquire locks.

Next post: the Lambda packaging bug.

---

## POST 16 — The Zip Packaging Bug: Wrong Directory Structure Silently Breaking Handler Imports

After fixing IAM, Lambda deployed but failed with Runtime.ImportModuleError: No module named 'src'. The handler was set to `src.lambda_handler.handler`, but the zip file didn't include the `src/` directory structure.

The packaging script was doing `cd src && zip -r ../lambda_function.zip .`. This zipped the contents of src/, not src/ itself. The zip had `lambda_handler.py` at the root, not `src/lambda_handler.py`.

The fix: change to `zip -r lambda_function.zip src/`. This includes the src/ directory in the zip. Now `src.lambda_handler` imports correctly.

This is why testing packaging matters. The code was correct. The handler path was correct. But the zip structure was wrong. Lambda couldn't find the module because it wasn't packaged correctly.

Next post: the API Gateway 404.

---

## POST 17 — API Gateway 404 Not Found: Event Parsing for HTTP API v2

After fixing packaging, Lambda deployed. But API Gateway returned 404 Not Found for /health. The Lambda logs showed the event was received. The handler was running. But the routing wasn't working.

The problem: API Gateway HTTP API v2 has a different event format than v1. The path and httpMethod are in different places. I was checking `event.get("path")` and `event.get("httpMethod")`, but in v2 they're in `event.get("requestContext", {}).get("http", {})`.

The fix: check multiple locations. Try `event.get("path")` first, then `event.get("rawPath")`, then `requestContext.http.path`. Same for httpMethod. Handle both v1 and v2 formats.

This is why reading AWS documentation matters. The event structure changed between API versions. My code assumed v1 format. It needed to handle v2.

Next post: tests passing but feature missing.

---

## POST 18 — Tests Passing, Feature Missing: The run_id Flow Was Never Wired Up

I wrote tests for the GitHub API integration. All 47 tests passed. I deployed to production. Then I hit the API with a real workflow run_id. Response: `{"error": "Missing required field: logs"}`.

The tests passed because they were testing the wrong thing. I had GitHubClient and WorkflowAnalyzer classes fully implemented and tested. But they weren't connected to the /analyze endpoint.

The endpoint only accepted direct logs: `{"logs": "..."}`. It had no handler for `{"owner": "...", "repo": "...", "run_id": 123}`. The code existed. The tests passed. But the feature didn't work.

I'd built all the pieces but forgot to wire them together. This is why integration tests matter. Unit tests verify components work in isolation. Integration tests verify they work together.

Next post: wiring it up.

---

## POST 19 — Wiring It Up: Request Format Detection and Restoring _analyze_workflow()

The fix was simple. Add request format detection in the handler. If the request has owner/repo/run_id, route to _analyze_workflow(). Otherwise, route to _analyze_logs().

I restored the _analyze_workflow() function. It uses GitHubClient to fetch workflow data and jobs. Then it calls WorkflowAnalyzer to analyze them. Returns structured JSON.

The detection logic: `if all(k in body for k in ("owner", "repo", "run_id")): return _analyze_workflow(...)`. Simple. But I'd missed it the first time.

I deployed. Hit the API with a real run_id. It worked. The workflow data was fetched. The analysis was returned. But error_message was always null.

Next post: why error_message was null.

---

## POST 20 — Silent Failure: try/except Swallowing the Real Error with No Log Trace

The GitHub API integration worked. Logs were being fetched. But error_message was always null. I added diagnostic logging to see what was happening.

The logs showed: "Analyzing workflow run" then immediately "END RequestId". No log fetching activity. No errors. Just silence.

The problem: a try/except block was swallowing the failure. The log fetching code was wrapped in try/except with no logging. If it failed, it failed silently. parsed_logs was set to an empty dict. The analyzer continued with no logs.

I added logging before the try block, inside the try block, and in the except block. Now I could see: "Fetching logs for run_id=...", "Raw logs fetched: 9355 bytes", "Parsed log files: ['0_Deploy to AWS.txt']". The logs were being fetched and parsed. But error_message was still null.

Next post: the log matching bug.

---

## POST 21 — Log Filenames vs Log Content: Why error_message Was Always Null

The logs were fetched. They were parsed. But error_message was null. I added more logging. The parsed logs had files like "0_Deploy to AWS.txt" and "Deploy to AWS/system.txt". The step name was "Terraform Plan". No match.

The problem: I was matching step names against log filenames. GitHub organizes logs by job name, not step name. The step content is inside the job log file, marked with `##[group]Run <step name>`.

The step name "Terraform Plan" doesn't match the filename "Deploy to AWS.txt". I needed to search inside the log content, not match filenames.

This is why understanding data structures matters. I assumed logs were organized by step. They're organized by job. Steps are marked inside job logs. I needed to parse the content, not the filename.

Next post: the diagnostic approach.

---

## POST 22 — The Diagnostic Approach: Adding Logging Before Fixing Anything

Before changing any logic, I added diagnostic logging. Log every outcome. Log when logs are fetched. Log the byte count. Log the parsed filenames. Log when matching fails. Log when matching succeeds.

The logs showed: logs fetched (9355 bytes), parsed (2 files), matching attempted (no match found). Now I knew exactly where it was failing. The matching logic.

I could have guessed. I could have assumed. But logging showed the truth. The logs were there. The parsing worked. The matching didn't. Now I knew what to fix.

This is why logging before debugging matters. Don't change code until you understand what's happening. Add logging. See the data flow. Then fix the actual problem.

Next post: the fix.

---

## POST 23 — The Fix: Searching Log Content for GitHub Actions Step Markers

I rewrote the matching logic. Instead of matching step names against filenames, search log content for GitHub Actions step markers. GitHub uses `##[group]Run <step name>` to mark step boundaries.

The new logic: search all log files for a line containing `##[group]Run <step name>`. Once found, extract the first line containing "error", "Error", "failed", or "Error:" after that marker. If no step marker is found, fall back to searching all log content for error lines related to the step's error_type.

If still nothing found, leave error_message as None. Never raise. Graceful degradation.

I added a test: `test_analyze_step_extracts_error_from_job_log`. It passes a parsed_logs dict with a job-level log file containing a step marker and an error line. Asserts error_message is populated correctly.

All 52 tests passed. I deployed. Hit the API. error_message now contains actual log content: "Error: Error acquiring the state lock" instead of null.

Next post: v1 ships.

---

## POST 24 — v1 Ships: error_message Returns "Error: Error acquiring the state lock"

The feature works. Real workflows. Real errors. Real analysis. I hit the API with a failed workflow run_id. The response includes error_message with actual log content extracted from GitHub Actions logs.

The journey from idea to working system took 51 commits over 4 days. 25 distinct issues. Each one a lesson. Each fix a step forward.

v1 is live. It analyzes failed workflows using pattern matching. It extracts error messages from logs. It provides root cause analysis and fix suggestions. It works.

But it's limited. It only handles the error patterns I've hardcoded. It doesn't understand context. It doesn't explain why the error happened, just what the error is.

Next post: what v2 looks like.

---

## POST 25 — What v2 Looks Like: Replacing Pattern Matching with an LLM

v1 uses regex patterns. Fast. Deterministic. Limited. v2 will use LLM-powered analysis. Instead of pattern matching, it'll read the full logs and generate contextual explanations.

The plan: keep pattern matching as fallback (fast, deterministic). Add LLM analysis for complex failures (comprehensive, contextual). Cache LLM responses to control costs. Keep the same API contract (backward compatible).

I'm also adding support for more CI/CD platforms (CircleCI, GitLab CI, Jenkins), historical analysis (trends over time), custom error pattern definitions, webhook integration for automatic analysis.

The goal: make debugging CI/CD failures as easy as asking a colleague who's seen it all before. Not just "here's the error" but "here's why it happened and how to prevent it."

If you want to follow along, the repo is public. I'm documenting every decision, every error, every fix. What CI/CD pain points should I tackle next?

---

## POST 26 — Gating Deploy on CI Success: Preventing Bad Deployments

I just fixed a formatting issue. Black formatting check failed in CI. I fixed it locally, but the deploy workflow still ran. It deployed code that would have failed the formatting check.

That's a problem. If CI fails, deploy shouldn't run. But my deploy workflow triggered on push, independent of CI. Two workflows running in parallel. CI could fail while deploy succeeded.

The fix: changed deploy trigger from `push` to `workflow_run`. Now deploy only runs after CI completes. Added a condition: `if: ${{ github.event.workflow_run.conclusion == 'success' }}`. If CI fails, deploy is skipped entirely.

This is infrastructure 101, but I missed it. Deploy should always gate on CI. No exceptions. Tests must pass. Linting must pass. Security scans must pass. Only then deploy.

Next post: what else did I miss?

---

## POST 27 — Terraform Backend Deprecation: dynamodb_table → use_lockfile

Terraform warned me about a deprecation. The S3 backend config used `dynamodb_table = "deploymentor-terraform-locks"`. Terraform 1.14+ deprecated it in favor of `use_lockfile = true`.

The difference: `dynamodb_table` required a DynamoDB table. `use_lockfile` stores the lock as a `.tflock` file in the S3 bucket itself. Simpler. Cheaper. No DynamoDB table needed.

I updated `terraform/main.tf` to use `use_lockfile = true`. Ran `terraform init -reconfigure`. Backend reinitialized cleanly. The deprecation warning disappeared.

But then CI failed. The GitHub Actions role couldn't delete the `.tflock` file. Missing `s3:DeleteObject` permission. I'd added it to Terraform, but Terraform couldn't apply because it needed that permission to release the lock.

Same bootstrapping problem as before. Fixed it directly via AWS CLI, then updated Terraform to match. The lock error disappeared. Deploy went green.

Lesson: deprecation warnings matter. They signal future breaking changes. Fix them early, even if they're just warnings.

Next post: what's next for v2?

---

## POST 28 — The Double Slash Bug: API Gateway Trailing Slash

I tested the API with the exact URL Terraform outputs. Got a 404. "No handler for POST //analyze". The path had a double slash.

The issue: Terraform's API Gateway output includes a trailing slash. When you append `/analyze`, you get `//analyze`. The handler only checked for `/analyze`. Double slash routes returned 404.

Lambda logs showed `path: //analyze`. The fix was one line: normalize the path before routing. Strip leading slashes, then add one back. `//health` becomes `/health`. `//analyze` becomes `/analyze`.

I added tests for both double slash and normal paths. All 54 tests pass. Both URL formats work now.

The lesson: always test with the exact URL your infrastructure outputs. Don't manually clean it. If Terraform says the URL is `https://api.example.com/`, test with that trailing slash. Your code should handle it.

Next post: what's next for v2?

---

## POST 29 — Three-Environment Lifecycle: Dev → Staging → Prod

I had a single environment. Every push to main deployed to prod. That's fine for a solo project, but it's not how real systems work. I needed a proper dev → staging → prod lifecycle.

The setup: three separate Terraform environments, each with its own state file. Dev auto-deploys on every push. Staging deploys manually or via `staging-*` tags. Prod deploys manually or via `v*` tags, never on push.

The tricky part: per-environment state files. I moved from a single `deploymentor/terraform.tfstate` to `deploymentor/dev/terraform.tfstate`, `deploymentor/staging/terraform.tfstate`, `deploymentor/prod/terraform.tfstate`. Each environment directory has its own backend config pointing to the right state key.

I created three workflows: deploy-dev.yml (auto on push), deploy-staging.yml (manual/tag), deploy-prod.yml (manual/tag with approval). Each workflow runs smoke tests after deployment. Prod workflow also verifies staging is healthy before deploying.

The result: fast iteration in dev, validation in staging, controlled releases to prod. No more accidental prod deployments from a random push.

Next post: why prod needs manual approval even when you're solo.

---

## POST 30 — Manual Approval Gate: Why Prod Needs a Pause Button

I added a manual approval gate to prod deployments. Even though I'm the only developer. Why? Because mistakes happen when you're moving fast.

The approval gate uses GitHub Environments. The workflow pauses at the "Deploy to Prod" job. GitHub shows a "Review deployments" button. You click it, review what's about to deploy, then approve or reject.

It's not about permission. It's about forcing a pause. Before prod deploys, you see exactly what's changing. You can verify staging is healthy. You can check the commit message. You can think "is this really ready?"

Without the gate, a typo in a commit message could trigger a prod deploy. A misconfigured workflow could deploy on the wrong branch. A rushed fix could break production. The approval gate stops all of that.

Even for solo projects, it's worth it. It enforces a "pause and think" moment. It creates an audit trail. It prevents "oops, I didn't mean to deploy that" moments.

The setup is manual in GitHub UI (environments, reviewers, protection rules). The workflow code just references the environment. But once it's set up, every prod deployment requires explicit approval.

Next post: what's next for v2?

---

## POST 31 — Fixing Workflow Overlap: The Old deploy.yml Problem

I had two workflows deploying to prod. The old `deploy.yml` triggered on every push to main and deployed to prod automatically. The new `deploy-prod.yml` was supposed to handle prod with approval gates. Both were running. Both deploying to prod. Both conflicting.

The old workflow used the old Terraform structure (`terraform/` not `terraform/environments/prod/`). It deployed to prod automatically on every push to main. That violated the one-direction flow. Main should only deploy to dev, not prod.

I disabled the old workflow. Renamed it to `deploy.yml.bak` with a comment explaining it was replaced. Now only one workflow deploys to each environment. Dev auto-deploys on main. Staging deploys on staging branch push. Prod deploys on prod branch push with approval.

The lesson: when refactoring workflows, disable the old ones first. Don't let them overlap. One workflow per environment. One trigger per workflow. Clear ownership.

Next post: why one-direction code flow matters.

---

## POST 32 — One-Direction Code Flow: Why Ancestry Checks Matter

I added ancestry checks to staging and prod workflows. Before deploying, the workflow verifies the commit exists in the previous environment's history. Staging checks main. Prod checks staging.

The check uses `git merge-base --is-ancestor`. If the commit hasn't passed through the previous environment, the deployment fails. No shortcuts. No direct pushes. No skipping environments.

Why this matters: even with branch protection, you could merge staging into prod without going through main. Or merge a feature branch directly into prod. The ancestry check prevents that. It enforces the flow: main → staging → prod.

The check is simple. It's fast. It's reliable. It catches mistakes before they reach production. It's infrastructure as code for deployment flow.

Even for solo projects, it's worth it. It prevents "oops, I merged the wrong branch" moments. It creates an audit trail. It enforces discipline.

The setup: staging workflow checks if commit exists in main. Prod workflow checks if commit exists in staging. Both fail fast if the check doesn't pass. No deployment, no confusion, no shortcuts.

Next post: what's next for v2?

---

## POST 33 — Two Workflows, One State Lock: The 412 PreconditionFailed Conflict

Two workflows triggered simultaneously on push to main. The old `deploy.yml` and the new `deploy-dev.yml`. Both tried to acquire the same Terraform state lock. Both failed with 412 PreconditionFailed.

The error: "Error acquiring the state lock. Another operation may be in progress." But there wasn't another operation. There were two operations. Two workflows. One state file. One lock.

I thought I'd disabled the old workflow. I renamed it to `.bak`. But GitHub Actions still ran it. The file was still in `.github/workflows/`. GitHub doesn't care about file extensions. It runs any `.yml` file in that directory.

The fix: move it completely out of the workflows directory. Rename it to `.disabled`. Add a comment explaining why. Force unlock the stuck state. Delete the leftover lock file in S3.

The lesson: when replacing workflows, don't just rename them. Move them out. Or delete them. GitHub will run any YAML file in `.github/workflows/`. Always audit for overlapping triggers when adding new workflows.

Next post: what's next for v2?

---

## POST 34 — Concurrency Controls: Preventing Simultaneous Deploy State Lock Conflicts

The deploy-dev workflow kept failing with state lock conflicts. Every run. 412 PreconditionFailed. The lock file was stuck in S3. But why was it stuck?

I found the root cause: multiple workflow runs were triggering simultaneously. Push to main. CI runs. Deploy Dev runs. But if you push again quickly, another Deploy Dev starts. Both try to acquire the same Terraform state lock. Both fail.

The fix: concurrency controls. Added to all three deploy workflows:
```yaml
concurrency:
  group: deploy-dev
  cancel-in-progress: false
```

This ensures only one deploy runs at a time per environment. If a second push happens while the first deploy is running, the second waits. No simultaneous runs. No lock conflicts.

The `cancel-in-progress: false` means the second run waits instead of being cancelled. This is safer for deployments. You want the latest code to deploy, but only after the current deploy finishes.

I also cleared the stuck lock file from S3 and force-unlocked the state. Then tested everything locally before pushing. The workflow now runs cleanly without lock conflicts.

The lesson: always add concurrency controls to deployment workflows. Especially when they modify shared state. Terraform state locks are there for a reason. Respect them.

Next post: what's next for v2?

---

## POST 35 — Missing Environment Variables: Terraform Plan Hanging in CI

Terraform plan was hanging in CI. No error message. Just waiting. The workflow timed out after 60 minutes. I checked the logs. Nothing. Just silence.

The problem: terraform plan was prompting for `var.environment` interactively. CI can't answer prompts. So it hung. Forever. Waiting for input that would never come.

The fix: add `-var="environment=dev"` to every terraform plan and apply command. All three workflows. Dev, staging, prod. Every single terraform command needs the environment variable explicitly passed.

I also added path filtering to CI. Now CI only runs when code, tests, terraform, or scripts change. Not on docs. Not on markdown. Saves CI minutes. Prevents unnecessary runs.

And I changed deploy-dev to use workflow_run. It only triggers after CI succeeds. No more direct push triggers. Cleaner flow. CI runs. If it passes, deploy runs. If it fails, nothing deploys.

The lesson: always pass required variables explicitly in CI/CD. Never rely on prompts. Never assume defaults. Be explicit. Every command. Every time.

Next post: what's next for v2?

---

## POST 36 — Relative Paths Break When You Move Directories

Terraform plan was failing. Couldn't find `lambda_function.zip`. The error: "no such file or directory". But the zip exists. I checked. It's at the repo root. So why can't Terraform find it?

The problem: relative paths. The module used `${path.root}/../lambda_function.zip`. That worked when Terraform ran from `terraform/`. But we moved to `terraform/environments/dev/`. Now `path.root` points to the environment directory. Going up one level (`../`) lands in `terraform/environments/`, not the repo root.

The fix: go up three levels. `${path.root}/../../../lambda_function.zip`. From `terraform/environments/dev/`, that's: up to `environments/`, up to `terraform/`, up to repo root. There's the zip.

I tested it locally for all three environments. Dev, staging, prod. All work. The path resolves correctly. Terraform plan completes without errors.

The lesson: when you restructure directories, check every relative path. Especially in modules. Especially when `path.root` changes. Test locally before pushing. One character difference (`../` vs `../../../`) breaks everything.

Next post: what's next for v2?

---

## POST 37 — The Import Script That Ran When Nothing Existed

The deploy workflow was failing. Import script errors. Resources not found. But wait — dev resources don't exist yet. Why is the import script running?

The problem: the import script ran unconditionally for every environment. It tried to import resources that were never created. For fresh environments like dev and staging, Terraform should create everything from scratch. No imports needed.

The fix: check if resources exist before importing. Added a Lambda existence check:
```bash
LAMBDA_EXISTS=$(aws lambda get-function --function-name deploymentor-dev ...)
if [ "$LAMBDA_EXISTS" = "NOT_FOUND" ]; then
  echo "No existing resources — Terraform will create them fresh"
else
  echo "Existing resources found — running import script"
  ./terraform-import-existing.sh dev
fi
```

Now the workflow handles both scenarios. Fresh environments skip import. Existing environments import correctly. The import script only runs when it should.

The lesson: don't assume resources exist. Check first. Conditional logic prevents unnecessary errors. Makes workflows work for both fresh deployments and existing infrastructure.

Next post: what's next for v2?

---

## POST 38 — The Stale Lock That Blocked Every Deploy

The deploy workflow was failing. State lock error. Every single run. The lock file was stuck in S3. Left behind by a local terraform plan that crashed. CI couldn't acquire the lock. Deploys blocked.

The problem: local terraform runs create lock files in S3. If the process crashes or is interrupted, the lock stays. CI tries to run terraform. Can't acquire the lock. Fails. Manual cleanup required every time.

The fix: automatic lock cleanup before every terraform operation. Added a step that checks for stale locks and clears them:
```bash
LOCK_EXISTS=$(aws s3 ls s3://.../terraform.tfstate.tflock ...)
if [ "$LOCK_EXISTS" = "EXISTS" ]; then
  echo "⚠️  Stale lock found — clearing it"
  aws s3 rm s3://.../terraform.tfstate.tflock
fi
```

Now every deploy checks for stale locks first. Clears them automatically. No more manual intervention. Deploys work reliably even after local terraform runs crash.

The lesson: assume local operations can leave stale state. Build cleanup into CI/CD. Automatic recovery beats manual fixes every time. One small step prevents hours of debugging.

Next post: what's next for v2?

---

## POST 39 — Automating the Manual Setup

I was setting up branch protection rules. Clicking through the GitHub UI. Step by step. Main, staging, prod. Then environments. More clicking. More manual steps. Then I realized — this is all API calls. Why am I clicking?

The problem: setup guides had manual UI steps. Click here, click there, select this, save that. Repetitive. Error-prone. Not reproducible. Every new instance required the same manual work.

The fix: replaced all manual steps with GitHub CLI commands. Branch protection? JSON files and `gh api`. Environments? Same. Reviewers? Same. Everything automated. One script runs it all.

Now setup is:
```bash
# Create JSON files
cat > branch_protection.json << 'EOF'
{...}
EOF

# Apply via CLI
gh api repos/.../branches/main/protection --method PUT --input branch_protection.json
```

The lesson: if it's in the API, automate it. CLI commands are reproducible. Version controlled. Shareable. Manual steps are not. Automation beats documentation every time.

Next post: what's next for v2?

---

## POST 40 — The DevOps Audit: What I Missed

I ran a full DevOps best practices audit. Read everything. Checked every workflow, every Terraform file, every line of code. The result: 7/10. Good, but not great.

The critical issues: IAM role has wildcard permissions. API Gateway has no authentication. No retry logic for GitHub API calls. No CloudWatch alarms. Lambda timeout might be too short.

The important issues: Hardcoded account IDs. No workflow timeouts. Missing ancestry checks. No structured logging. No reserved concurrency.

The good news: OIDC is set up correctly. State is isolated. Resources are tagged. Tests are comprehensive. Documentation is solid.

The lesson: Building something that works is different from building something that's production-ready. The audit found 30 issues. Five are critical. Fifteen are important. Ten are nice-to-have.

I'm fixing them in priority order. IAM wildcards first. Then API auth. Then retry logic. Then alarms. One at a time. No shortcuts.

Next post: fixing the critical issues.

---

## POST 41 — The Five Critical Fixes Before v2

I fixed all five critical issues from the audit. Here's what changed and why.

**Fix 1: Lambda timeout** — Increased from 30 to 60 seconds. Added a timeout guard that returns 503 if less than 5 seconds remain. Large workflow runs were timing out silently. Now they fail fast with a clear error.

**Fix 2: IAM wildcard permissions** — Replaced `Resource = "*"` with scoped ARNs. Lambda permissions now only apply to `deploymentor-*` functions. IAM permissions only to `deploymentor-*` roles. Logs only to `deploymentor-*` log groups. Removed `sts:AssumeRole` entirely — it wasn't needed. The GitHub Actions role can no longer access resources outside the deploymentor namespace.

**Fix 3: Lambda packaging** — Updated all three deploy workflows to install dependencies into `package/`, zip them first, then add source code. Before: `zip -r lambda_function.zip src/` (source only). After: dependencies included directly in the zip. This is required for v2 when we add the Anthropic SDK. The package is now 17MB instead of a few KB.

**Fix 4: Reserved concurrency** — Added `reserved_concurrent_executions = 10`. No more unlimited concurrency. If 10 requests are running, the 11th waits. This prevents cost spikes from traffic bursts or abuse. When v2 adds LLM calls, this becomes even more important.

**Fix 5: API Gateway authentication** — Added API key validation for `/analyze` endpoint only. `/health` stays public. API key is stored in SSM at `/deploymentor/{env}/api_key`. Lambda validates the `x-api-key` header. Returns 401 if missing, 403 if invalid. Backward compatible: if `API_KEY_SSM_PARAM` isn't set, validation is skipped.

All tests pass. Terraform validates. Code is formatted. Ready to commit.

Next post: deploying these fixes and verifying they work in production.

---

## POST 43 — When Reserved Concurrency Breaks Your Deploy

Terraform apply failed. Error: "ReservedConcurrentExecutions decreases account's UnreservedConcurrentExecution below its minimum value of 10". The Lambda function had `reserved_concurrent_executions = 10` set. AWS accounts have a minimum unreserved concurrency of 10. Setting reserved concurrency to 10 would drop the account below that minimum.

The fix: Set dev environment to unreserved concurrency (`-1`). Dev doesn't need guaranteed capacity. It needs to not break. Staging and prod keep their reserved limits. They need predictable performance.

The lesson: Reserved concurrency is a trade-off. Guaranteed capacity vs. account-level limits. For dev, choose flexibility. For prod, choose guarantees. Know your account limits before reserving.

Next post: the DevOps audit that found 30 issues.

---

## POST 44 — The DevOps Audit: 30 Issues, 8 Critical Fixes, One Day

I ran a full DevOps audit. 30 issues found. 5 critical, 15 important, 10 nice-to-have. Maturity score: 7/10. Not bad, but not production-ready.

The critical ones: IAM wildcard permissions (Resource = "*" for CloudWatch), no retry logic for GitHub API calls, hardcoded AWS account IDs, missing workflow timeouts, no CloudWatch alarms. The important ones: no ancestry check in staging workflow, no coverage threshold enforcement, inconsistent error handling.

I fixed 8 items in one day. Scoped all IAM permissions to `deploymentor-*` resources only. Added retry logic with exponential backoff to GitHub client. Replaced hardcoded account IDs with `data.aws_caller_identity.current.account_id`. Added 30-minute timeouts to all deploy workflows. Created three CloudWatch alarms (errors, duration, throttles) with SNS notifications. Added ancestry check to staging. Enforced 50% coverage threshold (we're at 71%).

Maturity score: 8.5/10. The audit wasn't about perfection. It was about knowing what's broken before someone else finds it.

Next post: the SNS taint incident that blocked deployment.

---

## POST 45 — When Terraform State Gets Tainted: The SNS Topic Incident

Deploy failed. Terraform plan showed "1 to destroy" for the SNS topic. The topic was marked as tainted from a previous failed apply. Terraform wanted to destroy and recreate it, but the delete would fail because DeleteTopic permission was added in the same run — too late.

The diagnosis: The SNS topic existed in AWS and Terraform state, but was tainted. Terraform couldn't read its tags without ListTagsForResource permission, but couldn't update the IAM role without successfully planning. Chicken and egg.

The fix: Delete the topic from AWS, remove it from Terraform state, let Terraform create it fresh. Clean slate. The topic was recreated with all CloudWatch alarms attached. Deploy passed. Smoke tests passed.

The lesson: Tainted resources are Terraform's way of saying "this resource is suspect, replace it." Sometimes the fastest fix is to delete and recreate. Sometimes you untaint. Know when to use each approach.

Next post: the IAM bootstrapping anti-pattern.

---

## POST 46 — The IAM Bootstrapping Anti-Pattern: When Your Role Can't Update Itself

Started today with PR #1 merge (docs update). Then hit the reserved concurrency issue — dev Lambda couldn't deploy because setting reserved_concurrent_executions to 10 would drop the account's unreserved concurrency below AWS's minimum of 10. Fixed by setting dev to -1 (unreserved).

Ran a full 30-item DevOps audit. Maturity score: 7/10. Implemented 8 critical fixes in one commit and deployed to dev. Then hit the SNS taint incident — a previous failed apply left the SNS topic tainted in Terraform state. Fix was to delete the topic from AWS, remove it from state, and let Terraform recreate it cleanly.

But the real problem was deeper. Every time I added a new AWS service (SNS, then budgets), the deploy failed with a missing permission error. The GitHub Actions role needed the permission to apply, but the permission wasn't live until after the apply succeeded. Chicken and egg.

The root cause: the GitHub Actions role was managing its own permissions through the deploy workflow. I kept manually patching IAM via CLI to unblock applies, which created drift and wasn't sustainable.

Refactored to terraform/bootstrap/. IAM is now managed separately by a local admin run. Deploy workflows no longer touch IAM at all. Added three improvements: cost budget alerts at $5/month, Mermaid architecture diagrams in the codebase explanation, and automated prod rollback on smoke test failure.

End state: bootstrap applied cleanly, dev deploy green, all features live. No more manual IAM patches. The pattern works.

Next post: rate limiting at the Gateway level.

---

## POST 47 — Rate Limiting: When Your GitHub Token Has a Hard Limit

GitHub's API has a hard limit: 5,000 requests per hour. One bad actor could exhaust it and break the service. Rate limiting wasn't optional — it was necessary.

Added API Gateway stage-level throttling: 10 burst (max concurrent), 5 requests per second sustained. Why at Gateway level not Lambda? Requests rejected before Lambda invokes. No cost, no token usage, no wasted resources.

The safety process: plan-only first, confirmed in-place update (no destroy/recreate), smoke tests passed. PR #13 merged, all CI checks green.

The defaults are conservative (10/5) for a personal/dev tool. Production can increase if legitimate traffic requires it. But the pattern is set: Gateway-level rate limiting protects both cost and availability.

Next post: when Gateway-level auth isn't possible.

---

## POST 48 — When API Gateway Auth Isn't Possible: HTTP API v2 Limitations

Investigated moving API key enforcement to API Gateway infra level. Discovered HTTP API v2 does not support `api_key_required` on routes. That is a REST API v1 feature only.

Evaluated alternatives. JWT authorizer: overkill for a simple API key. Lambda authorizer: invokes Lambda twice per request, defeats the cost-saving purpose entirely. Migrate to REST API v1: more expensive and complex.

Decision: keep auth in Lambda. It is the correct and idiomatic approach for HTTP APIs. Single Lambda invocation validates the key, rejects immediately if invalid. No double invocation, no extra cost, no complexity.

Reverted to last stable state on main using git checkout. Cleaned up partial Terraform state from the failed apply. Lesson learned: always check API type (HTTP vs REST) before designing auth strategy. They have fundamentally different capability sets.

Next post: what v2 will add.

---

## POST 49 — S3 + CloudFront Frontend: No VPC, No Servers, Just Static Hosting

Added a real UI for DeployMentor. Not a dashboard — a single page: API key, repo (owner/repo), run ID, Analyze button. Result: status badge (FAILED/PASSED), workflow name, failed job, failed step, error type, error message in a scrollable code block, suggestions as a list.

Why S3 + CloudFront? No VPC, no EC2, no containers. Terraform already manages Lambda, API Gateway, IAM. Adding a static site is one module: S3 bucket (block all public access), Origin Access Control, bucket policy allowing only CloudFront, CloudFront distribution with that origin. Fits the existing AWS setup perfectly. Same story: everything as code, same deploy pipeline.

The frontend is pure HTML + vanilla JS + Tailwind CDN. No build step. No frameworks. Form calls POST /analyze with owner, repo, run_id and x-api-key. Response is parsed and rendered. Error messages often contain ANSI escape codes from Terraform or CLI output — we strip them before display with a simple regex so you see plain text, not terminal color codes.

Config is injected at deploy time. Repo has placeholders in frontend/config.js (REPLACE_WITH_API_URL, REPLACE_WITH_ENV). CI/CD after Terraform Apply does sed to replace them with the real API URL and environment name, then syncs frontend/ to S3 and invalidates CloudFront. So no hardcoded URLs in the repo; each environment gets the right backend URL automatically.

Live URL: after deploy, run `terraform output frontend_url` in the environment directory. Open that CloudFront URL, enter API key (from SSM), repo, run ID, click Analyze. Same flow as the API, but in a browser. CloudFront invalidation runs on every deploy so you always get the latest files.

Next post: what v2 will add.

---

## Technical Details

**Tech Stack:**
- AWS Lambda (Python 3.12)
- API Gateway HTTP API
- Terraform for IaC
- GitHub Actions with OIDC
- SSM Parameter Store for secrets
- CloudWatch for logging

**Cost:** ~$5-10/month (Lambda free tier + minimal API Gateway usage)

**Architecture:** Serverless, event-driven, scales to zero

**Security:** Least privilege IAM, no hardcoded secrets, OIDC authentication

**Status:** v1 deployed and working. Analyzing real GitHub Actions workflows.

**Repository:** [github.com/BamiseOmolaso/deploymentor](https://github.com/BamiseOmolaso/deploymentor)

**Stats:**
- 72+ commits documenting the journey
- 54+ tests passing (71% coverage)
- 46+ distinct issues encountered and resolved
- Real workflows being analyzed in production
- CI/CD workflow gating implemented
- Terraform backend modernized (use_lockfile)
- Path normalization for API Gateway trailing slash
- Three-environment lifecycle (dev/staging/prod) with manual approval gate
- One-direction code flow enforced (main → staging → prod) with ancestry checks
- CI workflow auto-triggers on PRs with proper permissions
- Dev Lambda uses unreserved concurrency to prevent account limit errors
- DevOps maturity: 8.5/10 (improved from 7/10)
- All IAM permissions scoped to deploymentor-* resources only
- CloudWatch alarms configured for errors, duration, and throttles
- Retry logic added to GitHub API client
- All 8 audit fixes deployed and verified in dev environment
- Bootstrap IAM pattern implemented (IAM managed separately from deploy workflows)
- Cost budget alerts configured at $5/month
- Lambda versioning and automated prod rollback implemented
- API Gateway rate limiting configured (10 burst, 5 req/s sustained)
