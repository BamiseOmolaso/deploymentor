# DeployMentor Implementation Plan

## 📋 Step-by-Step Todo List

This document tracks our implementation progress. Each step includes:
- **What** we're doing
- **Why** it's important
- **How** we'll verify it works

---

## Step 1: Complete SSM Integration in GitHub Client ⏳

**Status:** Pending approval

**What:**
- Replace `NotImplementedError` in `src/github/client.py` with actual SSM parameter retrieval
- Use the existing `src/utils/ssm.py` utility function
- Read the SSM parameter path from environment variable

**Why:**
- This is the foundation for secure secret management
- Enables the GitHub client to authenticate with GitHub API
- Required before we can test or deploy

**Changes:**
- Update `_get_token_from_ssm()` method in `GitHubClient`
- Import `get_parameter` from `src.utils.ssm`
- Read `GITHUB_TOKEN_SSM_PARAM` from environment

**Verification:**
- Code review shows SSM integration
- No `NotImplementedError` in code
- Proper error handling for missing parameters

---

## Step 2: Set Up Local Development Environment ⏳

**Status:** Pending approval

**What:**
- Create Python virtual environment using Python 3.12
- Install production and development dependencies
- Verify setup works

**Why:**
- Enables local testing and development
- Ensures consistent Python version (matches Lambda runtime)
- Required before running tests

**Commands:**
```bash
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

**Verification:**
- `python --version` shows 3.12.x
- `pip list` shows all dependencies installed
- Can import modules without errors

---

## Step 3: Add Environment Variable Fallback for Local Dev ⏳

**Status:** Pending approval

**What:**
- Allow `GITHUB_TOKEN` environment variable for local development
- Fallback to SSM only when running in Lambda
- Update GitHub client initialization logic

**Why:**
- Makes local development easier (no need for AWS credentials)
- Allows testing without deploying to AWS
- Follows common development patterns

**Changes:**
- Check for `GITHUB_TOKEN` env var first
- Fall back to SSM if env var not found
- Add clear logging for which method is used

**Verification:**
- Can initialize GitHubClient with env var locally
- Falls back to SSM in Lambda environment
- Logs indicate which method was used

---

## Step 4: Run Tests Locally ⏳

**Status:** Pending approval

**What:**
- Run existing test suite
- Verify all tests pass
- Check code formatting and linting

**Why:**
- Ensures our changes don't break existing functionality
- Validates code quality
- Establishes baseline before adding new features

**Commands:**
```bash
pytest tests/ -v
black --check src/ tests/
flake8 src/ tests/
```

**Verification:**
- All tests pass
- Code formatting is correct
- No linting errors

---

## Step 5: Create Basic Workflow Analyzer ⏳

**Status:** Pending approval

**What:**
- Implement `src/analyzers/workflow_analyzer.py`
- Parse GitHub workflow logs
- Identify common error patterns
- Return structured analysis

**Why:**
- Core functionality of DeployMentor
- Transforms raw logs into actionable insights
- Foundation for AI integration later

**Features:**
- Parse workflow run data
- Extract failed job information
- Identify error patterns (timeout, dependency, syntax, etc.)
- Return structured JSON response

**Verification:**
- Can analyze sample workflow data
- Returns structured error information
- Handles edge cases gracefully

---

## Step 6: Add /analyze API Endpoint ⏳

**Status:** Pending approval

**What:**
- Add POST `/analyze` endpoint to Lambda handler
- Accept GitHub workflow run details (owner, repo, run_id)
- Call analyzer and return results

**Why:**
- Exposes functionality via API
- Enables integration with GitHub webhooks
- Makes the service usable

**Changes:**
- Update `lambda_handler.py` routing
- Add request validation
- Integrate GitHub client and analyzer
- Return formatted response

**Verification:**
- Can call `/analyze` endpoint
- Returns analysis results
- Handles errors appropriately

---

## Step 7: Add Tests for GitHub Client ⏳

**Status:** Pending approval

**What:**
- Create `tests/test_github_client.py`
- Test SSM integration with mocks
- Test API calls with mocked responses
- Test error handling

**Why:**
- Ensures GitHub client works correctly
- Validates SSM integration
- Prevents regressions

**Test Cases:**
- SSM parameter retrieval
- GitHub API calls
- Error handling (missing token, API errors)
- Environment variable fallback

**Verification:**
- All tests pass
- Good test coverage
- Tests use mocks (no real API calls)

---

## Step 8: Add Tests for Analyzer ⏳

**Status:** Pending approval

**What:**
- Create `tests/test_analyzer.py`
- Test workflow analysis logic
- Test error pattern detection
- Test edge cases

**Why:**
- Ensures analyzer works correctly
- Validates analysis logic
- Prevents regressions

**Test Cases:**
- Successful analysis
- Different error types
- Empty/malformed data
- Edge cases

**Verification:**
- All tests pass
- Good test coverage
- Tests are comprehensive

---

## Step 9: Create SSM Parameter Script ⏳

**Status:** Pending approval

**What:**
- Test `scripts/setup-ssm-parameter.sh`
- Create SSM parameter in AWS
- Verify parameter exists

**Why:**
- Required for Lambda to authenticate with GitHub
- Tests our deployment scripts
- Validates AWS access

**Commands:**
```bash
./scripts/setup-ssm-parameter.sh <github-token>
aws ssm get-parameter --name /deploymentor/github/token --with-decryption
```

**Verification:**
- Script runs successfully
- Parameter created in SSM
- Can retrieve parameter value

---

## Step 10: Deploy Infrastructure to Dev ✅

**Status:** Completed (with minor issue)

**What:**
- ✅ Terraform initialized
- ✅ Infrastructure planned
- ✅ Resources deployed (11 resources)
- ⚠️ Lambda code update pending (dependency issue)

**Why:**
- Creates AWS resources (Lambda, API Gateway)
- Tests infrastructure as code
- Enables end-to-end testing

**Results:**
- ✅ Lambda function: `deploymentor-dev`
- ✅ API Gateway: Get from `terraform output api_gateway_url`
- ✅ IAM roles and policies created
- ⚠️ Lambda needs dependency update (`requests` module)

**Next Steps:**
- Fix Lambda dependencies (see REMAINING_TASKS.md)
- Test `/health` endpoint
- Test `/analyze` endpoint

---

## 🎯 Current Status

**Next Step:** Step 1 - Complete SSM Integration in GitHub Client

**Ready to proceed?** Review Step 1 above and approve to continue.

---

## 📝 Notes

- Each step is independent and can be reviewed separately
- Steps build on each other, so order matters
- We'll wait for approval before proceeding
- Each step includes verification steps

