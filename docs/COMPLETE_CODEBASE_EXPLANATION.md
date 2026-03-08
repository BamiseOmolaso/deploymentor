# DeployMentor: Complete Codebase Explanation

> A comprehensive guide explaining every component, tool, and decision in the DeployMentor project from scratch.

---

## Table of Contents

1. [The Big Picture](#the-big-picture)
2. [The Problem We're Solving](#the-problem-were-solving)
3. [The Solution Architecture](#the-solution-architecture)
4. [Technology Stack Deep Dive](#technology-stack-deep-dive)
5. [Project Structure](#project-structure)
6. [Code Components Explained](#code-components-explained)
7. [Infrastructure as Code (Terraform)](#infrastructure-as-code-terraform)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Security Architecture](#security-architecture)
10. [Data Flow Diagrams](#data-flow-diagrams)
11. [How Everything Works Together](#how-everything-works-together)
12. [Setup and Configuration](#setup-and-configuration)
13. [DevOps Best Practices](#devops-best-practices)

---

## The Big Picture

### What is DeployMentor?

DeployMentor is a **serverless AI agent** that analyzes failed GitHub Actions workflow runs. Instead of manually digging through logs, you send a workflow run ID to an API, and it returns:
- What went wrong (root cause)
- Why it happened (explanation)
- How to fix it (actionable steps)

### The Core Value Proposition

**Before DeployMentor:**
```
Failed workflow → Open logs → Scroll through 1000+ lines → 
Search for "error" → Copy error to Stack Overflow → 
Hope someone has seen it → Spend 10-15 minutes debugging
```

**After DeployMentor:**
```
Failed workflow → POST run_id to API → Get structured analysis → 
Know exactly what to fix → Fix it in 2 minutes
```

---

## The Problem We're Solving

### The Pain Points

1. **Log Overload**: GitHub Actions logs can be thousands of lines. Finding the actual error is like finding a needle in a haystack.

2. **Context Switching**: You have to switch between GitHub, Stack Overflow, documentation, and your code editor to understand what went wrong.

3. **Time Waste**: Every failed workflow costs 10-15 minutes of debugging time. Multiply that by multiple failures per day, and it adds up.

4. **Knowledge Gap**: Junior developers or developers new to a stack might not recognize common error patterns.

### Example Scenario

Your Terraform deployment fails. The logs show:
```
Error: Error acquiring the state lock
...
LockID:    deploymentor-terraform-locks
...
This means another process is running Terraform against this state.
```

**Without DeployMentor**: You might not understand this is a state lock issue. You might think it's a permissions problem or a network issue.

**With DeployMentor**: The API returns:
```json
{
  "error_type": "terraform",
  "error_message": "Error acquiring the state lock",
  "probable_cause": "Another Terraform process is holding the state lock",
  "fix_steps": [
    "Check if another terraform apply is running",
    "If stuck, use 'terraform force-unlock <LOCK_ID>'",
    "Verify no other CI/CD pipelines are running simultaneously"
  ]
}
```

---

## The Solution Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User/Developer                            │
│              (Has a failed GitHub Actions run)               │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ POST /analyze
                        │ { "owner": "...", "repo": "...", "run_id": 123 }
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              API Gateway HTTP API                            │
│         (Public endpoint, handles routing)                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Invokes Lambda
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              AWS Lambda Function                             │
│              (Python 3.12, runs analysis)                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Lambda       │  │ GitHub       │  │ Workflow     │     │
│  │ Handler      │→ │ Client       │→ │ Analyzer     │     │
│  │ (Routes)     │  │ (Fetches)    │  │ (Analyzes)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└───────┬──────────────────┬──────────────────┬──────────────┘
        │                  │                  │
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ GitHub API   │  │ SSM Parameter│  │ CloudWatch   │
│ (Workflow    │  │ Store        │  │ (Logging)    │
│  data/logs)  │  │ (GitHub      │  │              │
│              │  │  token)      │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

### Request Flow

```
1. User sends POST request to API Gateway
   ↓
2. API Gateway routes to Lambda function
   ↓
3. Lambda handler parses request (run_id or direct logs)
   ↓
4. If run_id: GitHubClient fetches workflow data from GitHub API
   ↓
5. GitHubClient fetches logs (zip file) from GitHub API
   ↓
6. GitHubClient parses zip file into log dictionary
   ↓
7. WorkflowAnalyzer analyzes workflow data + logs
   ↓
8. Analyzer matches error patterns and extracts error messages
   ↓
9. Analyzer generates fix suggestions
   ↓
10. Lambda returns structured JSON response
   ↓
11. API Gateway returns response to user
```

---

## Technology Stack Deep Dive

### 1. AWS Lambda

**What it is**: Serverless compute service. You upload code, AWS runs it when triggered. No servers to manage.

**Why we use it**:
- **Cost**: Pay only when code runs. Free tier: 1M requests/month free
- **Scalability**: Automatically scales from 0 to thousands of concurrent executions
- **No maintenance**: No servers to patch, update, or monitor
- **Fast deployment**: Upload code, it's live in seconds

**How we set it up**:
- **Runtime**: Python 3.12 (latest supported by AWS)
- **Memory**: 256 MB (enough for our workload)
- **Timeout**: 30 seconds (workflow analysis shouldn't take longer)
- **Handler**: `src.lambda_handler.handler` (entry point function)

**Code location**: `src/lambda_handler.py`

### 2. API Gateway HTTP API

**What it is**: Managed service that creates HTTP endpoints for your Lambda functions. Handles routing, CORS, authentication.

**Why we use it**:
- **HTTP API vs REST API**: HTTP API is cheaper ($1 per million requests vs $3.50)
- **Automatic scaling**: Handles millions of requests
- **Built-in features**: CORS, access logging, request/response transformation
- **No infrastructure**: Fully managed by AWS

**How we set it up**:
- **Type**: HTTP API (not REST API - cheaper)
- **Protocol**: HTTP/HTTPS
- **Routes**: 
  - `GET /health` → Health check
  - `POST /analyze` → Main analysis endpoint
  - `$default` → Catch-all route to Lambda
- **CORS**: Enabled for all origins (can restrict in production)

**Code location**: `terraform/modules/api_gateway/main.tf`

### 3. AWS Systems Manager (SSM) Parameter Store

**What it is**: Secure storage for configuration data and secrets. Think of it as a secure key-value store.

**Why we use it**:
- **Security**: Encrypted at rest (SecureString type)
- **Cost**: Free for standard parameters
- **Integration**: Lambda can read directly with IAM permissions
- **No hardcoded secrets**: Secrets never in code or Terraform

**How we set it up**:
- **Parameter path**: `/deploymentor/github/token`
- **Type**: SecureString (encrypted)
- **Access**: Lambda IAM role has read permission
- **Setup**: Created manually via AWS CLI or script

**Code location**: 
- Setup script: `scripts/setup-ssm-parameter.sh`
- Usage: `src/utils/ssm.py`

### 4. Terraform

**What it is**: Infrastructure as Code (IaC) tool. You write configuration files that describe your infrastructure, and Terraform creates/manages it.

**Why we use it**:
- **Reproducibility**: Same code creates same infrastructure every time
- **Version control**: Infrastructure changes tracked in git
- **State management**: Terraform tracks what it created (prevents drift)
- **Modularity**: Reusable modules for common patterns

**How we set it up**:
- **Backend**: S3 bucket for state storage + `use_lockfile` for locking (stores `.tflock` files in S3)
- **Modules**: 
  - `lambda/` - Lambda function configuration
  - `api_gateway/` - API Gateway configuration
  - `github_oidc/` - GitHub OIDC setup for CI/CD
- **State**: Stored remotely in S3 (not in git)

**Code location**: `terraform/` directory

### 5. GitHub Actions

**What it is**: CI/CD platform built into GitHub. Runs workflows (scripts) on events like push, pull request, etc.

**Why we use it**:
- **Free**: Free for public repos
- **Integration**: Already using GitHub for code
- **OIDC**: Can authenticate to AWS without storing keys
- **Automation**: Deploys automatically on code changes

**How we set it up**:
- **Workflow**: `.github/workflows/deploy.yml`
- **Trigger**: Push to `main` branch
- **Authentication**: OIDC (no AWS keys stored)
- **Steps**: Package → Terraform init → Terraform apply → Health check

**Code location**: `.github/workflows/deploy.yml`

### 6. Python 3.12

**What it is**: Programming language. Latest version supported by AWS Lambda.

**Why we use it**:
- **Lambda support**: AWS Lambda supports Python 3.12
- **Libraries**: Rich ecosystem (requests, boto3)
- **Readability**: Easy to understand and maintain
- **Performance**: Fast enough for our use case

**Dependencies**:
- **Production** (`requirements.txt`):
  - `boto3` - AWS SDK for Python
  - `requests` - HTTP library for GitHub API calls
- **Development** (`requirements-dev.txt`):
  - `pytest` - Testing framework
  - `black` - Code formatter
  - `flake8` - Linter
  - `moto` - AWS service mocking for tests

---

## Project Structure

```
deploymentor/
├── src/                          # Application source code
│   ├── lambda_handler.py        # Main Lambda entry point
│   ├── analyzers/                # Analysis logic
│   │   ├── workflow_analyzer.py # Analyzes GitHub Actions workflows
│   │   └── log_analyzer.py      # Analyzes raw logs
│   ├── github/                  # GitHub API integration
│   │   └── client.py            # GitHub API client
│   └── utils/                   # Utility functions
│       └── ssm.py               # SSM Parameter Store helper
│
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main configuration
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── bootstrap/               # Backend setup (S3 with use_lockfile)
│   └── modules/                 # Reusable modules
│       ├── lambda/              # Lambda function module
│       ├── api_gateway/         # API Gateway module
│       └── github_oidc/         # GitHub OIDC module
│
├── tests/                        # Test files
│   ├── test_lambda_handler.py  # Lambda handler tests
│   ├── test_github_client.py    # GitHub client tests
│   └── test_analyzer.py         # Analyzer tests
│
├── scripts/                      # Utility scripts
│   ├── package-lambda.sh        # Package Lambda function
│   ├── setup-ssm-parameter.sh   # Create SSM parameter
│   └── terraform-import-existing.sh # Import existing resources
│
├── .github/                      # GitHub configuration
│   └── workflows/               # CI/CD workflows
│       ├── ci.yml               # Continuous Integration
│       └── deploy.yml           # Deployment workflow
│
├── docs/                         # Documentation
│   ├── ARCHITECTURE.md          # Architecture overview
│   ├── DEPLOYMENT.md            # Deployment guide
│   └── ...                      # Other docs
│
├── requirements.txt              # Production dependencies
├── requirements-dev.txt          # Development dependencies
└── README.md                     # Project overview
```

---

## Code Components Explained

### 1. Lambda Handler (`src/lambda_handler.py`)

**Purpose**: Entry point for all API Gateway requests. Routes requests to appropriate handlers.

**Key Functions**:

#### `handler(event, context)`
- **What it does**: Main entry point called by Lambda
- **Input**: API Gateway event (contains HTTP method, path, body)
- **Output**: API Gateway response (status code, headers, body)
- **Flow**:
  1. Logs sanitized request (no sensitive data)
  2. Extracts HTTP method and path from event
  3. **Normalizes path**: Handles double slashes from API Gateway trailing slash
     - Example: `//health` → `/health`, `//analyze` → `/analyze`
     - This ensures routes work whether API Gateway URL has trailing slash or not
  4. Routes to appropriate handler:
     - `GET /health` → `_health_check()`
     - `POST /analyze` → `_analyze()`
     - Everything else → 404

#### `_health_check()`
- **What it does**: Returns service health status
- **Use case**: Monitoring, load balancer health checks
- **Response**: `{"status": "healthy", "service": "deploymentor", "version": "0.1.0"}`

#### `_analyze(event)`
- **What it does**: Main analysis endpoint
- **Request formats**:
  1. **GitHub run_id**: `{"owner": "...", "repo": "...", "run_id": 123}`
  2. **Direct logs**: `{"source": "github_actions", "logs": "..."}`
- **Flow**:
  1. Parses request body
  2. Detects format (run_id vs logs)
  3. Routes to `_analyze_workflow()` or `_analyze_logs()`

#### `_analyze_workflow(owner, repo, run_id)`
- **What it does**: Analyzes a GitHub Actions workflow run
- **Flow**:
  1. Validates run_id is integer
  2. Creates GitHubClient and WorkflowAnalyzer
  3. Fetches workflow data from GitHub API
  4. Fetches and parses logs (zip file)
  5. Analyzes workflow + logs
  6. Returns structured analysis

#### `_analyze_logs(body)`
- **What it does**: Analyzes raw log text
- **Use case**: When you have logs but not a run_id
- **Flow**:
  1. Validates logs field exists
  2. Creates LogAnalyzer
  3. Analyzes logs using pattern matching
  4. Returns structured analysis

### 2. GitHub Client (`src/github/client.py`)

**Purpose**: Handles all interactions with GitHub API. Fetches workflow data and logs.

**Key Components**:

#### `GitHubClient` Class
- **Initialization**: 
  - Token resolution order:
    1. Explicit token parameter (for testing)
    2. `GITHUB_TOKEN` environment variable (local dev)
    3. SSM Parameter Store (Lambda/production)
  - **Retry Logic**: HTTPAdapter with Retry strategy configured
    - 3 retry attempts with exponential backoff (backoff_factor=1)
    - Retries on: 429 (rate limit), 500, 502, 503, 504 (server errors)
    - All requests have 30-second timeout to prevent hanging
- **Session**: Uses `requests.Session()` with authentication headers

#### `get_workflow_run(owner, repo, run_id)`
- **What it does**: Fetches workflow run metadata
- **GitHub API**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}`
- **Returns**: Workflow run data (status, conclusion, timestamps, etc.)

#### `get_workflow_run_jobs(owner, repo, run_id)`
- **What it does**: Fetches jobs for a workflow run
- **GitHub API**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`
- **Returns**: List of jobs with steps, status, conclusions

#### `get_workflow_run_logs(owner, repo, run_id)`
- **What it does**: Fetches logs as zip file
- **GitHub API**: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`
- **Returns**: Raw bytes (zip file)
- **Note**: Logs expire after 90 days

#### `parse_logs_zip(log_bytes)`
- **What it does**: Parses zip file into dictionary
- **Input**: Raw zip file bytes
- **Output**: Dictionary mapping filename → log content
- **Error handling**: Returns empty dict on any error (never raises)

### 3. Workflow Analyzer (`src/analyzers/workflow_analyzer.py`)

**Purpose**: Analyzes GitHub Actions workflow data to identify failures and root causes.

**Key Components**:

#### `ERROR_PATTERNS` Dictionary
- **What it is**: Maps error types to regex patterns
- **Error types**: timeout, dependency, syntax, permission, network, resource, configuration, terraform
- **Example**:
  ```python
  "terraform": [
      r"terraform.*error",
      r"terraform.*failed",
      r"Error acquiring the state lock"
  ]
  ```

#### `analyze(workflow_run, jobs, logs)`
- **What it does**: Main analysis function
- **Input**:
  - `workflow_run`: Workflow metadata
  - `jobs`: Jobs data with steps
  - `logs`: Parsed log files (optional)
- **Output**: Structured analysis with:
  - `failed`: Boolean
  - `root_cause`: Primary failure
  - `error_types`: List of detected error types
  - `job_analyses`: Per-job analysis
  - `suggestions`: Fix recommendations

#### `_get_failed_jobs(jobs)`
- **What it does**: Filters jobs to only failed ones
- **Logic**: Job conclusion == "failure"

#### `_analyze_job(job, logs)`
- **What it does**: Analyzes a single job
- **Returns**: Job analysis with:
  - Job name, status, conclusion
  - Failed steps count
  - Step analyses
  - Error type

#### `_analyze_step(step, logs)`
- **What it does**: Analyzes a single step
- **Log matching**:
  1. Searches log content for step markers (`##[group]Run <step name>`)
  2. Extracts error lines after step marker
  3. Falls back to error_type keyword search
- **Returns**: Step analysis with:
  - Step name, status, conclusion
  - Error type
  - Error message (extracted from logs)

#### `_identify_error_type(step_name, step_conclusion, error_message)`
- **What it does**: Matches step against error patterns
- **Logic**: Checks step name and error message against ERROR_PATTERNS

#### `_generate_suggestions(error_types)`
- **What it does**: Generates fix suggestions based on error types
- **Example**: Terraform errors → "Check state lock", "Verify backend config"

### 4. Log Analyzer (`src/analyzers/log_analyzer.py`)

**Purpose**: Analyzes raw log text (when run_id is not available).

**Key Components**:

#### `ERROR_PATTERNS` Dictionary
- **What it is**: Maps error types to patterns + fix suggestions
- **Error types**: iam_permissions, file_not_found, python_module, terraform_backend, docker_build, timeout, network
- **Structure**:
  ```python
  "iam_permissions": {
      "patterns": [r"AccessDenied", ...],
      "summary": "IAM permissions issue detected",
      "probable_cause": "...",
      "fix_steps": ["...", "..."],
      "confidence": 0.9
  }
  ```

#### `analyze(logs, source)`
- **What it does**: Analyzes log text
- **Input**: Log string, source type
- **Output**: Analysis with summary, cause, fix steps, confidence
- **Logic**: Searches logs for patterns, returns first match

### 5. SSM Utility (`src/utils/ssm.py`)

**Purpose**: Helper functions for AWS SSM Parameter Store.

**Key Functions**:

#### `get_parameter(name, decrypt=True)`
- **What it does**: Retrieves parameter from SSM
- **Input**: Parameter name (e.g., `/deploymentor/github/token`)
- **Output**: Parameter value or None
- **Error handling**: Returns None if not found, raises on other errors

---

## Infrastructure as Code (Terraform)

### Directory Structure

```
terraform/
├── main.tf                    # Main configuration
├── variables.tf              # Input variables
├── outputs.tf               # Output values
├── terraform.tfvars.example  # Example variable values
├── bootstrap/                # Backend setup
│   ├── main.tf              # S3 bucket + DynamoDB table
│   └── README.md            # Setup instructions
└── modules/                  # Reusable modules
    ├── lambda/              # Lambda function
    ├── api_gateway/         # API Gateway
    └── github_oidc/         # GitHub OIDC
```

### Main Configuration (`terraform/main.tf`)

**Backend Configuration**:
```hcl
backend "s3" {
  bucket         = "deploymentor-terraform-state"
  key            = "deploymentor/terraform.tfstate"
  region         = "us-east-1"
  use_lockfile = true
  encrypt      = true
}
```

**Why S3 with use_lockfile**:
- **S3**: Stores Terraform state file (tracks what was created)
- **use_lockfile**: Stores state lock as `.tflock` file in S3 (prevents concurrent modifications)
- **Encryption**: State file encrypted at rest
- **Cost**: ~$0.02/month (S3 free tier only, no DynamoDB needed)
- **Note**: The GitHub Actions role requires `s3:DeleteObject` permission to release locks

**Modules**:
1. **Lambda Module**: Creates Lambda function, IAM role, CloudWatch log group
2. **API Gateway Module**: Creates HTTP API, routes, integration, stage
3. **GitHub OIDC Module**: Creates IAM role for GitHub Actions

### Lambda Module (`terraform/modules/lambda/`)

**Resources Created**:
- `aws_lambda_function`: The actual Lambda function
- `aws_iam_role`: Execution role for Lambda
- `aws_iam_policy`: Permissions (CloudWatch Logs, SSM read)
- `aws_cloudwatch_log_group`: Log storage

**Key Configuration**:
- **Handler**: `src.lambda_handler.handler`
- **Runtime**: `python3.12`
- **Timeout**: 60 seconds (with timeout guard in handler)
- **Memory**: 256 MB (default)
- **Reserved Concurrency**: 
  - **Dev**: `-1` (unreserved) - Prevents account-level concurrency limit errors
  - **Staging/Prod**: `10` (default) - Reserved capacity for predictable performance
- **Layers**: Lambda Layer with `requests` library
- **Environment variables**: `GITHUB_TOKEN_SSM_PARAM`, `ENVIRONMENT`, `API_KEY_SSM_PARAM`

**Lambda Zip Path Resolution**:
- **Zip location**: Created at repo root as `lambda_function.zip` by the deploy workflow
- **Path resolution**: Uses `${path.root}/../../../lambda_function.zip`
  - `path.root` points to the environment directory (`terraform/environments/{env}/`)
  - Goes up 3 levels (`../../../`) to reach repo root
  - Works for all environments (dev, staging, prod) automatically
- **Why this matters**: When Terraform runs from `terraform/environments/dev/`, relative paths must account for the directory structure. The original path `${path.root}/../lambda_function.zip` only went up one level, which was correct when running from `terraform/` but broke when moved to environment subdirectories.

### API Gateway Module (`terraform/modules/api_gateway/`)

**Resources Created**:
- `aws_apigatewayv2_api`: HTTP API
- `aws_apigatewayv2_integration`: Lambda integration
- `aws_apigatewayv2_route`: Default route (`$default`)
- `aws_apigatewayv2_stage`: Deployment stage
- `aws_lambda_permission`: Allows API Gateway to invoke Lambda
- `aws_cloudwatch_log_group`: API Gateway access logs

**Key Configuration**:
- **Protocol**: HTTP (not REST)
- **CORS**: Enabled for all origins
- **Auto-deploy**: Changes deploy automatically
- **Authentication**: Dual-layer authentication for `/analyze` endpoint
  - **Layer 1 (Lambda-level)**: API key validation via `x-api-key` header (implemented in `_validate_api_key()`)
  - **Layer 2 (Gateway-level)**: HTTP API v2 doesn't support API keys at Gateway level like REST API does
  - API keys stored in SSM Parameter Store at `/deploymentor/{environment}/api_key`
  - Lambda-level validation provides defence in depth and is performant (no additional latency)
  - `/health` endpoint remains public (no authentication required)
  - **Note**: If Gateway-level auth is required in the future, consider migrating to REST API or using a Lambda authorizer

### GitHub OIDC Module (`terraform/modules/github_oidc/`)

**Resources Created**:
- `aws_iam_openid_connect_provider`: GitHub OIDC provider
- `aws_iam_role`: Role for GitHub Actions
- `aws_iam_role_policy`: Permissions for Terraform operations

**Permissions**:
- Lambda: Create, update, get function
- API Gateway: Create, update, get API
- S3: Read/write/delete Terraform state bucket (including `.tflock` files for state locking)
- CloudWatch: Create log groups
- IAM: Read roles/policies (for imports)
- **Note**: `s3:DeleteObject` is required for `use_lockfile` to release state locks

---

## CI/CD Pipeline

### Workflow Architecture

The CI/CD pipeline consists of multiple workflows that implement a dev → staging → prod deployment lifecycle:

1. **CI Workflow** (`.github/workflows/ci.yml`): Runs on every push/PR
   - Code quality checks (formatting, linting)
   - Unit tests
   - Security scans
   - Terraform validation

2. **Deploy Dev Workflow** (`.github/workflows/deploy-dev.yml`): Auto-deploys to dev after CI passes
   - Triggers on `workflow_run` when CI completes successfully on `main`
   - Only runs if CI workflow conclusion is `success`
   - Deploys to dev environment
   - Runs smoke tests after deployment
   - Uses `-var="environment=dev"` in all terraform commands

3. **Deploy Staging Workflow** (`.github/workflows/deploy-staging.yml`): Manual or tag-based staging deployment
   - Triggers on `workflow_dispatch` or git tag `staging-*`
   - Deploys to staging environment
   - Runs smoke tests after deployment

4. **Deploy Prod Workflow** (`.github/workflows/deploy-prod.yml`): Production deployment with manual approval
   - Triggers on `workflow_dispatch` or git tag `v*` (never on push)
   - Three jobs: verify-staging → deploy (with approval gate) → verify-prod
   - Requires manual approval before deploying to production

### CI Workflow (`.github/workflows/ci.yml`)

**Trigger**: 
- Push to `main`, `staging`, or `prod` branches
- Pull requests to `main`, `staging`, or `prod`
- **Path filtering**: Only runs on changes to:
  - `src/**` - Source code changes
  - `tests/**` - Test file changes
  - `terraform/**` - Infrastructure changes
  - `scripts/**` - Script changes
  - `requirements*.txt` - Dependency changes
  - `.github/workflows/**` - Workflow changes
- **Does NOT run on**: `docs/**`, `*.md`, or other non-code changes

**Jobs**:

1. **Lint & Format Check**:
   - Black formatting check
   - isort import sorting check
   - Flake8 linting
   - MyPy type checking (non-blocking)

2. **Run Tests**:
   - Full test suite with pytest
   - Code coverage reporting
   - Uploads coverage to Codecov

3. **Security Scan**:
   - Safety check for vulnerable dependencies
   - Hardcoded secrets detection

4. **Terraform Validate**:
   - Terraform format check
   - Terraform validation

**All jobs must pass** for CI to be considered successful.

**Test Coverage**: CI enforces a minimum coverage threshold of 50% (`--cov-fail-under=50`). Current coverage is 71%, providing a safety margin. This prevents regressions that reduce test coverage below acceptable levels.

**Workflow Timeouts**: All deploy workflows have a 30-minute timeout (`timeout-minutes: 30`) to prevent hanging runs from consuming resources indefinitely. If a deploy takes longer than 30 minutes, it's automatically cancelled.

### Environment Lifecycle

**Dev Environment**:
- **Purpose**: Fast iteration, testing new features
- **Trigger**: Every push to `main` (automatic)
- **State**: `deploymentor/dev/terraform.tfstate`
- **SSM Parameter**: `/deploymentor/dev/github/token`
- **No approval required**: Auto-deploys after CI passes

**Staging Environment**:
- **Purpose**: Pre-production testing, validation before prod
- **Trigger**: Manual (`workflow_dispatch`) or git tag `staging-*`
- **State**: `deploymentor/staging/terraform.tfstate`
- **SSM Parameter**: `/deploymentor/staging/github/token`
- **Optional approval**: Can be configured with reviewers

**Prod Environment**:
- **Purpose**: Production workload, real users
- **Trigger**: Manual (`workflow_dispatch`) or git tag `v*` (never on push)
- **State**: `deploymentor/prod/terraform.tfstate`
- **SSM Parameter**: `/deploymentor/prod/github/token`
- **Manual approval required**: Workflow pauses for explicit approval

### Disabled Workflow (`.github/workflows/deploy.yml.disabled`)

**Status**: DISABLED - replaced by environment-specific workflows

The original `deploy.yml` workflow has been disabled and renamed to `deploy.yml.disabled`. It was causing state lock conflicts with `deploy-dev.yml` because both workflows were triggering on push to `main` and trying to acquire the same Terraform state lock.

**Why it was disabled**:
- Overlapped with `deploy-dev.yml` (both triggered on push to main)
- Used old Terraform structure (`terraform/` not `terraform/environments/dev/`)
- Deployed to prod automatically (violated one-direction flow)
- Caused 412 PreconditionFailed errors when both workflows ran simultaneously

**Replacement**: The functionality has been split into three environment-specific workflows:
- `deploy-dev.yml` - Dev environment (auto on main)
- `deploy-staging.yml` - Staging environment (push to staging)
- `deploy-prod.yml` - Prod environment (push to prod + approval)

The file is kept for reference only. Do not re-enable.

### Deploy Dev Workflow (`.github/workflows/deploy-dev.yml`)

**Trigger**: 
- `workflow_run` - Triggers when CI workflow completes on `main` branch
- Only runs if CI workflow conclusion is `success`
- Manual (`workflow_dispatch`) - Can be triggered manually for testing

**Conditional Execution**:
```yaml
if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
```
This ensures deploy-dev only runs after CI passes, or when manually triggered.

**Concurrency Control**:
```yaml
concurrency:
  group: deploy-dev
  cancel-in-progress: false
```
This ensures only one deploy-dev workflow runs at a time. If multiple pushes happen quickly, subsequent runs wait for the current one to finish. Prevents Terraform state lock conflicts.

**Environment**: `development` (GitHub environment)

**Flow**:
1. CI workflow runs on push to `main` (if paths match)
2. If CI passes, Deploy Dev workflow runs automatically
3. **Lock cleanup**: Checks for stale Terraform state lock in S3 and clears it if found
   - Prevents state lock errors from local terraform runs that were interrupted
   - Automatically recovers from stale locks without manual intervention
4. Terraform plan/apply uses `-var="environment=dev"` to prevent interactive prompts
5. **Conditional import**: Checks if `deploymentor-dev` Lambda exists in AWS
   - If NOT_FOUND: skips import, Terraform creates resources fresh
   - If exists: runs import script to sync existing resources into state
6. Deploys to dev environment
7. Runs smoke tests after deployment

**No approval required** - deploys automatically after CI passes.

**Smoke Tests**:
After deployment, the workflow runs smoke tests (`scripts/smoke-test.sh dev`) which validate:
1. **Health check endpoint** (`GET /health`) - Public endpoint, no authentication required
2. **Unauthenticated analyze request** - Should be rejected with 401/403
3. **Authenticated analyze request** - Should succeed with valid API key from SSM
4. **Error detection** - Verifies that failed workflows are correctly identified

The smoke test script fetches the API key from SSM Parameter Store at `/deploymentor/{environment}/api_key` and includes it in the `x-api-key` header for authenticated requests.

**Terraform Variables**: All terraform commands explicitly pass `-var="environment=dev"` to prevent CI from hanging on interactive prompts.

**State Lock Protection**: The concurrency control prevents simultaneous runs from fighting over the same Terraform state lock, eliminating 412 PreconditionFailed errors.

**Conditional Import Logic**: The workflow checks if resources exist before attempting to import them. This handles both scenarios:
- **Fresh environments**: First deployment, no resources exist → Terraform creates everything
- **Existing environments**: Resources already exist → Import script syncs them into Terraform state

### Deploy Staging Workflow (`.github/workflows/deploy-staging.yml`)

**Trigger**:
- Push to `staging` branch
- Manual (`workflow_dispatch`)

**Environment**: `staging` (GitHub environment)

**Jobs** (run in sequence):

1. **verify-ancestry**: 
   - Verifies the commit exists in `main` branch history
   - Uses `git merge-base --is-ancestor` to check ancestry
   - Fails if commit hasn't passed through main
   - Enforces one-direction flow: main → staging

2. **deploy**:
   - **Lock cleanup**: Checks for stale Terraform state lock in S3 and clears it if found
   - **Conditional import**: Checks if `deploymentor-staging` Lambda exists in AWS
     - If NOT_FOUND: skips import, Terraform creates resources fresh
     - If exists: runs import script to sync existing resources into state
   - Deploys to staging environment
   - Runs smoke tests after deployment

**Lock Cleanup**: Prevents state lock errors from local terraform runs. Automatically clears stale locks before every Terraform operation.

**Conditional Import Logic**: Same as dev workflow - checks if resources exist before importing. Handles both fresh and existing deployments.

**Ancestry Check**:
The workflow ensures code has been in `main` before reaching staging. If you try to push code directly to staging that hasn't been in main, the deployment fails with:
```
❌ This commit has not passed through main. Aborting.
   Code must flow: main → staging → prod
```

**No approval required** - but code must have passed through main first.

### Deploy Prod Workflow (`.github/workflows/deploy-prod.yml`)

**Trigger**:
- Push to `prod` branch
- Manual (`workflow_dispatch`)
- Git tag `v*` (e.g., `v1.0.0`)

**Environment**: `production` (GitHub environment with approval gate)

**Jobs** (run in sequence):

1. **verify-ancestry**: 
   - Verifies the commit exists in `staging` branch history
   - Uses `git merge-base --is-ancestor` to check ancestry
   - Fails if commit hasn't passed through staging
   - Enforces one-direction flow: main → staging → prod

2. **verify-staging**: 
   - Runs smoke tests against staging environment
   - Ensures staging is healthy before deploying to prod
   - Depends on verify-ancestry passing

3. **deploy** (with approval gate):
   - Depends on both verify-ancestry and verify-staging passing
   - Pauses for manual approval (GitHub environment protection)
   - Requires explicit approval from configured reviewers
   - **Lock cleanup**: Checks for stale Terraform state lock in S3 and clears it if found
   - **Unconditional import**: Always runs import script (prod resources were pre-created manually)
   - Deploys to production after approval
   - Gets API URL and stores it for next job

**Lock Cleanup**: Same as dev and staging - automatically clears stale locks before Terraform operations. Prevents state lock errors from local terraform runs.

**Import Strategy**: Prod workflow always runs the import script because prod resources were manually created before Terraform managed them. Dev and staging use conditional imports to handle both fresh and existing deployments.

4. **verify-prod**:
   - Runs smoke tests against production
   - Fails if tests don't pass (triggers rollback consideration)

**Ancestry Check**:
The workflow ensures code has been in `staging` before reaching prod. If you try to push code directly to prod that hasn't been in staging, the deployment fails with:
```
❌ This commit has not passed through staging. Aborting.
   Code must flow: main → staging → prod
```

**Manual Approval Gate**:
```yaml
environment:
  name: production
  url: ${{ steps.get-url.outputs.api_url }}
```

This block creates a manual approval step. The workflow pauses at the "Deploy to Prod" job, and a reviewer must click "Review deployments" and approve before the deployment proceeds.

**Why manual approval for prod?**
- Prevents accidental deployments
- Allows review of changes before production
- Provides audit trail of who approved what
- Even for solo projects, it enforces a "pause and think" moment

**Enforced Flow**:
- Code must be in `main` (dev auto-deploys)
- Code must be in `staging` (staging deploys with ancestry check)
- Code must be in `prod` (prod deploys with ancestry check + approval)
- No shortcuts, no direct pushes, no skipping environments

### Workflow Gating Benefits

**Why gate deploy on CI success?**
- **Prevents bad deployments**: Code with failing tests never reaches production
- **Catches issues early**: Formatting/linting errors caught before deployment
- **Saves time**: No point deploying if tests fail
- **Security**: Security scans must pass before deployment
- **Infrastructure safety**: Terraform validation prevents invalid configs

**Flow Diagram**:
```
Push to main
    ↓
CI Workflow starts
    ↓
┌─────────────────┐
│ Lint & Format   │
│ Tests           │
│ Security Scan   │
│ Terraform Check │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
  Pass      Fail
    │         │
    │         └──→ Deploy skipped ❌
    │
    ▼
Deploy Workflow starts ✅
    ↓
Infrastructure deployment
    ↓
Health check
    ↓
Deployment complete ✅
```

### OIDC Authentication

**How it works**:
1. GitHub Actions requests OIDC token from GitHub
2. GitHub issues JWT token
3. GitHub Actions exchanges JWT for AWS credentials
4. AWS validates JWT against OIDC provider
5. AWS issues temporary credentials (valid for 1 hour)

**Why it's better than access keys**:
- **No secrets to rotate**: No AWS keys stored in GitHub
- **Temporary credentials**: Expire after 1 hour
- **Auditable**: AWS CloudTrail logs show which workflow assumed the role
- **Scoped**: Role has only necessary permissions

**Setup**: See `docs/GITHUB_OIDC_SETUP.md`

---

## Security Architecture

### Secrets Management

**GitHub Token**:
- **Storage**: SSM Parameter Store (`/deploymentor/github/token`)
- **Type**: SecureString (encrypted)
- **Access**: Lambda IAM role has read permission
- **Never**: In code, Terraform, or git

**AWS Credentials**:
- **CI/CD**: OIDC (no keys stored)
- **Local Dev**: AWS CLI credentials (not in repo)

### IAM Permissions (Least Privilege)

**Lambda Execution Role**:
- CloudWatch Logs: Write logs
- SSM Parameter Store: Read `/deploymentor/*` parameters only

**GitHub Actions Role**:
- Lambda: Create, update, get function (scoped to `deploymentor-*` resources)
- API Gateway: Create, update, get API (scoped to `deploymentor-*` resources)
- S3: Read/write/delete state bucket (including `.tflock` files for state locking)
- CloudWatch: Create log groups, PutMetricData (scoped to `deploymentor-*` metrics only)
- IAM: Read (for imports)
- **Note**: `s3:DeleteObject` is required for `use_lockfile` to release state locks
- **Security**: All permissions are scoped to `deploymentor-*` resources only (no wildcards on resource ARNs)

### Network Security

- **API Gateway**: Public (by design - it's an API)
- **Lambda**: No VPC (reduces cost and cold start time)
- **No hardcoded secrets**: All in SSM or environment variables

### Logging Security

**Sanitized Logging**:
- Lambda handler logs only: path, httpMethod, requestId
- Never logs: Full event, headers, body (may contain secrets)

---

## Data Flow Diagrams

### Complete Request Flow

```
┌─────────────┐
│   User      │
│  (curl)     │
└──────┬──────┘
       │
       │ POST /analyze
       │ { "owner": "user", "repo": "repo", "run_id": 123 }
       ▼
┌─────────────────────────────────────┐
│      API Gateway HTTP API           │
│  https://xxx.execute-api.../analyze │
└──────┬──────────────────────────────┘
       │
       │ Invokes Lambda
       ▼
┌─────────────────────────────────────┐
│      AWS Lambda Function             │
│                                      │
│  handler(event, context)            │
│    ↓                                 │
│  _analyze(event)                    │
│    ↓                                 │
│  _analyze_workflow(owner, repo, id) │
└──────┬──────────────────────────────┘
       │
       │ Creates GitHubClient
       ▼
┌─────────────────────────────────────┐
│      GitHubClient                    │
│                                      │
│  1. Get token from SSM              │
│     ↓                                │
│  2. get_workflow_run()              │
│     ↓                                │
│  3. get_workflow_run_jobs()         │
│     ↓                                │
│  4. get_workflow_run_logs()         │
│     ↓                                │
│  5. parse_logs_zip()                │
└──────┬──────────────────────────────┘
       │
       │ Fetches from GitHub API
       ▼
┌─────────────────────────────────────┐
│      GitHub API                      │
│  api.github.com                      │
│                                      │
│  GET /repos/{owner}/{repo}/         │
│      actions/runs/{run_id}          │
│  GET /repos/{owner}/{repo}/         │
│      actions/runs/{run_id}/jobs     │
│  GET /repos/{owner}/{repo}/         │
│      actions/runs/{run_id}/logs     │
└──────┬──────────────────────────────┘
       │
       │ Returns data
       ▼
┌─────────────────────────────────────┐
│      WorkflowAnalyzer                │
│                                      │
│  analyze(workflow_run, jobs, logs)  │
│    ↓                                 │
│  _get_failed_jobs()                 │
│    ↓                                 │
│  _analyze_job() for each job        │
│    ↓                                 │
│  _analyze_step() for each step      │
│    ↓                                 │
│  _identify_error_type()             │
│    ↓                                 │
│  _generate_suggestions()             │
└──────┬──────────────────────────────┘
       │
       │ Returns analysis
       ▼
┌─────────────────────────────────────┐
│      Lambda Response                 │
│  {                                   │
│    "statusCode": 200,                │
│    "body": {                         │
│      "failed": true,                 │
│      "root_cause": {...},            │
│      "error_types": [...],           │
│      "suggestions": [...]            │
│    }                                 │
│  }                                   │
└──────┬──────────────────────────────┘
       │
       │ Returns to API Gateway
       ▼
┌─────────────────────────────────────┐
│      API Gateway                     │
│  Returns HTTP 200 with JSON body     │
└──────┬──────────────────────────────┘
       │
       │ Returns to user
       ▼
┌─────────────┐
│   User      │
│  Gets       │
│  Analysis   │
└─────────────┘
```

### Token Retrieval Flow

```
┌─────────────────────────────────────┐
│      Lambda Function                 │
│  GitHubClient.__init__()            │
└──────┬──────────────────────────────┘
       │
       │ Calls _get_token()
       ▼
┌─────────────────────────────────────┐
│  1. Check GITHUB_TOKEN env var      │
│     (for local dev)                 │
└──────┬──────────────────────────────┘
       │
       │ Not found
       ▼
┌─────────────────────────────────────┐
│  2. Check GITHUB_TOKEN_SSM_PARAM   │
│     env var (parameter path)        │
└──────┬──────────────────────────────┘
       │
       │ Found: /deploymentor/github/token
       ▼
┌─────────────────────────────────────┐
│  3. Call SSM get_parameter()        │
│     with decrypt=True               │
└──────┬──────────────────────────────┘
       │
       │ Uses Lambda IAM role
       ▼
┌─────────────────────────────────────┐
│      SSM Parameter Store             │
│  /deploymentor/github/token          │
│  (SecureString, encrypted)           │
└──────┬──────────────────────────────┘
       │
       │ Returns decrypted token
       ▼
┌─────────────────────────────────────┐
│      GitHubClient                    │
│  Token stored in self.token          │
│  Used for all GitHub API calls       │
└─────────────────────────────────────┘
```

---

## How Everything Works Together

### End-to-End Example

**Scenario**: A Terraform deployment fails in GitHub Actions. You want to know why.

**Step 1: Get the run_id**
- Go to GitHub Actions tab
- Find the failed run
- Copy the run ID (e.g., `22705372586`)

**Step 2: Call the API**
```bash
curl -X POST https://xxx.execute-api.us-east-1.amazonaws.com/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "BamiseOmolaso",
    "repo": "deploymentor",
    "run_id": 22705372586
  }'
```

**Step 3: What happens behind the scenes**

1. **API Gateway** receives the request
2. **API Gateway** routes to Lambda function
3. **Lambda handler** parses request, detects `run_id` format
4. **Lambda handler** calls `_analyze_workflow()`
5. **GitHubClient** initializes:
   - Reads `GITHUB_TOKEN_SSM_PARAM` env var
   - Calls SSM to get GitHub token
   - Creates authenticated session
6. **GitHubClient** fetches workflow data:
   - `GET /repos/BamiseOmolaso/deploymentor/actions/runs/22705372586`
   - `GET /repos/.../actions/runs/22705372586/jobs`
   - `GET /repos/.../actions/runs/22705372586/logs` (zip file)
7. **GitHubClient** parses logs zip:
   - Extracts files: `0_Deploy to AWS.txt`, `Deploy to AWS/system.txt`
   - Converts to dictionary: `{filename: content}`
8. **WorkflowAnalyzer** analyzes:
   - Identifies failed jobs
   - For each failed job, analyzes steps
   - Searches log content for step markers
   - Extracts error messages
   - Matches error patterns
   - Generates suggestions
9. **Lambda** returns analysis JSON
10. **API Gateway** returns HTTP 200 with JSON body

**Step 4: Get the response**
```json
{
  "workflow_id": 22705372586,
  "workflow_name": "Deploy to AWS",
  "status": "completed",
  "conclusion": "failure",
  "failed_jobs_count": 1,
  "analysis": {
    "failed": true,
    "root_cause": {
      "job_id": 56532876585,
      "job_name": "Deploy to AWS",
      "error_type": "terraform",
      "step_analyses": [
        {
          "step_name": "Terraform Plan",
          "status": "failure",
          "error_type": "terraform",
          "error_message": "Error: Error acquiring the state lock"
        }
      ]
    },
    "suggestions": [
      "Check if another terraform apply is running",
      "If stuck, use 'terraform force-unlock <LOCK_ID>'",
      "Verify no other CI/CD pipelines are running simultaneously"
    ]
  }
}
```

**Step 5: Fix the issue**
- Check if another Terraform process is running
- If stuck, use `terraform force-unlock`
- Re-run the workflow

---

## Key Design Decisions

### Why Serverless?

- **Cost**: Pay only when code runs. Free tier covers most usage.
- **Scalability**: Automatically handles traffic spikes.
- **Maintenance**: No servers to manage, patch, or monitor.

### Why HTTP API vs REST API?

- **Cost**: HTTP API is 70% cheaper ($1 vs $3.50 per million requests).
- **Performance**: Lower latency.
- **Features**: We don't need REST API features (API keys, usage plans, etc.).

### Why SSM Parameter Store vs Secrets Manager?

- **Cost**: SSM is free for standard parameters. Secrets Manager costs $0.40/month per secret.
- **Features**: We don't need Secrets Manager features (automatic rotation, etc.).
- **Simplicity**: SSM is simpler for our use case.

### Why Terraform vs CloudFormation?

- **Multi-cloud**: Terraform works with multiple clouds (we might expand later).
- **State management**: Terraform state is more flexible.
- **Community**: Larger module ecosystem.

### Why GitHub Actions vs AWS CodePipeline?

- **Integration**: Already using GitHub for code.
- **Cost**: Free for public repos.
- **OIDC**: Built-in support for AWS OIDC.

### Why Python 3.12?

- **Lambda support**: Latest Python version supported by AWS Lambda.
- **Libraries**: Rich ecosystem (requests, boto3).
- **Readability**: Easy to understand and maintain.

---

## Cost Breakdown

### Monthly Costs (Estimated)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1M requests @ 256MB, 100ms avg | ~$0.20 |
| API Gateway | 1M requests | ~$1.00 |
| CloudWatch Logs | 7-day retention | ~$0.50 |
| SSM Parameter Store | 1 parameter | Free |
| S3 (state backend) | <5GB storage | Free (free tier) |
| S3 (state lock via use_lockfile) | <5GB storage | Free (free tier) |
| **Total** | | **~$1.70/month** |

### Free Tier Coverage

- **Lambda**: 1M requests/month free
- **API Gateway**: 1M requests/month free
- **S3**: 5GB storage free (includes state and lock files)

**For low usage, you may pay $0/month!**

---

## Testing Strategy

### Unit Tests

- **Location**: `tests/` directory
- **Framework**: `pytest`
- **Coverage**:
  - Lambda handler routing
  - GitHub client token retrieval
  - Workflow analyzer error detection
  - Log analyzer pattern matching

### Integration Tests

- **Health check**: Verify API is accessible
- **End-to-end**: Test full request flow with real GitHub API (mocked)

### CI/CD Tests

- **Formatting**: `black --check`
- **Linting**: `flake8`
- **Type checking**: `mypy` (non-blocking)
- **Terraform validation**: `terraform validate`

---

## Monitoring & Observability

### CloudWatch Logs

- **Lambda logs**: All executions logged automatically
- **API Gateway logs**: Access logs for debugging
- **Retention**: 7 days (cost optimization)

### Health Endpoint

- **Endpoint**: `GET /health`
- **Use case**: Monitoring, load balancer health checks
- **Response**: `{"status": "healthy", "service": "deploymentor", "version": "0.1.0"}`

### Metrics

- **Lambda**: Automatic metrics (invocations, errors, duration)
- **API Gateway**: Automatic metrics (requests, 4xx, 5xx errors)

### CloudWatch Alarms

Three alarms are configured for each Lambda function (enabled by default via `enable_alarms` variable):

1. **Error Alarm**:
   - **Metric**: Lambda Errors (Sum)
   - **Threshold**: 5 errors in 5 minutes
   - **Action**: SNS topic notification
   - **Use case**: Alert when function is failing frequently

2. **Duration Alarm**:
   - **Metric**: Lambda Duration (Average)
   - **Threshold**: 80% of timeout (e.g., 48 seconds for 60-second timeout)
   - **Evaluation**: 2 periods (10 minutes total)
   - **Action**: SNS topic notification
   - **Use case**: Alert when function is approaching timeout limit

3. **Throttle Alarm**:
   - **Metric**: Lambda Throttles (Sum)
   - **Threshold**: 1 throttle in 5 minutes
   - **Action**: SNS topic notification
   - **Use case**: Alert when function is being throttled (concurrency limit reached)

**SNS Topic**: Created automatically for each environment. Can be extended with email subscriptions or other integrations.

**Configuration**: Alarms can be disabled per environment by setting `enable_alarms = false` in the Lambda module.

**SNS Topic Management**: The SNS topic is created and managed by Terraform. If a topic becomes tainted in Terraform state (e.g., from a failed apply), the cleanest resolution is to delete it from AWS and remove it from Terraform state, then let Terraform recreate it fresh. This avoids permission issues that can occur when Terraform tries to destroy and recreate a tainted resource in the same apply.

---

## Future Enhancements

### v2 Features

1. **LLM-Powered Analysis**: Replace pattern matching with LLM for contextual explanations
2. **Multi-Platform Support**: CircleCI, GitLab CI, Jenkins
3. **Historical Analysis**: Track trends over time
4. **Webhook Integration**: Automatic analysis on workflow failure
5. **Custom Patterns**: User-defined error patterns

### Infrastructure Improvements

1. **CloudWatch Alarms**: Alert on error rates
2. **X-Ray Tracing**: Distributed tracing for debugging
3. **Rate Limiting**: Prevent abuse
4. **Caching**: Cache LLM responses to reduce costs

---

## Setup and Configuration

### Branch Protection Rules

Branch protection rules enforce one-direction code flow (main → staging → prod) and prevent direct pushes. They are set up using the GitHub CLI:

**Setup Method**: Automated via GitHub CLI (`gh api`)

**Required Rules**:
- **main**: Requires CI to pass, 1 approval, admin enforcement
- **staging**: Requires CI + Deploy Dev to pass, 1 approval, admin enforcement
- **prod**: Requires CI + Deploy Staging to pass, 1 approval, admin enforcement

**Documentation**: See [Branch Protection Setup Guide](BRANCH_PROTECTION_SETUP.md) for complete CLI commands.

### GitHub Environments

GitHub Environments provide OIDC authentication and manual approval gates. They are set up using the GitHub CLI:

**Environments**:
- **development**: Auto-deploys, no approval required
- **staging**: Auto-deploys, no approval required
- **production**: Requires manual approval from configured reviewers

**Setup Method**: Automated via GitHub CLI (`gh api`)

**Documentation**: See [GitHub Environment Setup Guide](GITHUB_ENVIRONMENT_SETUP.md) for complete CLI commands.

**Note**: After creating environments, you must add the `AWS_ROLE_ARN` secret to each environment using:
```bash
gh secret set AWS_ROLE_ARN --env <environment> --body <role_arn>
```

---

## DevOps Best Practices

### Audit Report

A comprehensive DevOps best practices audit was conducted on 2026-03-07, evaluating the codebase against industry standards for CI/CD, security, reliability, observability, and operational excellence.

**Overall DevOps Maturity: 8.5/10** (improved from 7/10)

**Key Findings** (Initial Audit):
- **Critical Issues (5)**: IAM wildcard permissions, no API authentication, no retry logic, Lambda timeout risk, no CloudWatch alarms
- **Important Issues (15)**: Hardcoded values, missing workflow timeouts, inconsistent workflows, no structured logging, no cost controls
- **Nice to Have (10)**: Enhanced observability, API versioning, rate limiting, distributed tracing

**What's Working Well**:
- ✅ OIDC authentication properly configured
- ✅ Remote state management with proper isolation
- ✅ Comprehensive test coverage (54 tests, 71% coverage)
- ✅ Consistent resource tagging
- ✅ Well-documented setup and deployment processes

**Priority Fixes** (All Completed - 2026-03-07):
1. ✅ Replace IAM wildcard permissions with specific resource ARNs — **FIXED**: All permissions now scoped to `deploymentor-*` resources only, including CloudWatch metrics
2. ✅ Add API Gateway authentication — **FIXED**: Dual-layer authentication (Lambda-level API key validation + note on Gateway-level limitations for HTTP API v2)
3. ✅ Implement retry logic for GitHub API calls — **FIXED**: HTTPAdapter with Retry (3 attempts, exponential backoff, 30s timeout) added to GitHubClient
4. ✅ Add CloudWatch alarms for Lambda errors and duration — **FIXED**: Three alarms configured (errors, duration, throttles) with SNS topic notifications
5. ✅ Remove hardcoded AWS account IDs — **FIXED**: All hardcoded account IDs replaced with `data.aws_caller_identity.current.account_id`

**Additional Fixes Completed** (2026-03-07):
- ✅ Added workflow timeouts (30 minutes) to all deploy workflows
- ✅ Added ancestry check to staging workflow (ensures code exists in main before deploying)
- ✅ Enforced test coverage threshold (50% minimum, currently at 71%)

**Additional Fixes Completed**:
- ✅ Increased Lambda timeout from 30 to 60 seconds with timeout guard
- ✅ Added reserved concurrency configuration:
  - Dev: `-1` (unreserved) to prevent account-level limit errors
  - Staging/Prod: `10` (reserved) for predictable performance
- ✅ Updated Lambda packaging to include runtime dependencies for v2 readiness

**Full Report**: See [DevOps Audit Report](DEVOPS_AUDIT_REPORT.md) for complete findings, explanations, and one-line fixes for all 30 identified issues.

---

## Conclusion

DeployMentor is a complete serverless application that demonstrates:

- **Modern architecture**: Serverless, event-driven, scalable
- **Security best practices**: No hardcoded secrets, least privilege IAM, OIDC
- **Infrastructure as Code**: Everything defined in Terraform
- **CI/CD automation**: Automated deployments via GitHub Actions
- **Cost optimization**: ~$1.70/month, potentially $0 with free tier
- **Automation**: Setup is fully automated via CLI (no manual UI steps)

The codebase is designed to be:
- **Maintainable**: Clear structure, well-documented
- **Testable**: Comprehensive test coverage
- **Extensible**: Easy to add new features
- **Production-ready**: Security, monitoring, error handling
- **Reproducible**: All setup steps are automated and version controlled

For deployment instructions, see [QUICKSTART.md](../QUICKSTART.md).  
For API usage, see [docs/API_USAGE.md](API_USAGE.md).  
For troubleshooting, see [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md).  
For branch protection setup, see [docs/BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md).  
For environment setup, see [docs/GITHUB_ENVIRONMENT_SETUP.md](GITHUB_ENVIRONMENT_SETUP.md).  
For DevOps best practices audit, see [docs/DEVOPS_AUDIT_REPORT.md](DEVOPS_AUDIT_REPORT.md).

