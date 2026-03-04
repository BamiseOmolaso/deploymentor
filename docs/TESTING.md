# Testing Guide

## Testing the `/analyze` Endpoint

### Prerequisites

1. **GitHub Token**: Must be configured in SSM Parameter Store (`/deploymentor/github/token`)
2. **Workflow Run ID**: A failed GitHub Actions workflow run ID

### Getting a Workflow Run ID

#### Option 1: From GitHub Web UI

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Find a failed workflow run (red X icon)
4. Click on the workflow run
5. Copy the run ID from the URL:
   ```
   https://github.com/OWNER/REPO/actions/runs/RUN_ID
   ```
   The `RUN_ID` is the number at the end of the URL

#### Option 2: Using GitHub CLI

```bash
# List recent workflow runs
gh run list --limit 10

# Get details of a specific run
gh run view RUN_ID
```

#### Option 3: Using GitHub API

```bash
# List workflow runs for a repository
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/runs

# Find a failed run
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/runs?status=failure
```

### Testing the Endpoint

#### Basic Test

```bash
# Get API URL from Terraform output
API_URL=$(terraform output -raw api_gateway_url)
curl -X POST $API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "your-username",
    "repo": "your-repo",
    "run_id": 123456789
  }'
```

#### Expected Response (Success)

```json
{
  "workflow_id": 123456789,
  "workflow_name": "CI",
  "status": "completed",
  "conclusion": "failure",
  "failed_jobs_count": 1,
  "analysis": {
    "failed": true,
    "root_cause": {
      "job_id": 987654321,
      "job_name": "test",
      "error_type": "dependency",
      "step_analyses": [...]
    },
    "error_types": ["dependency"],
    "suggestions": [
      "Dependency installation failed. Review package manager logs..."
    ]
  }
}
```

#### Expected Response (Not Found)

```json
{
  "error": "Workflow run not found: owner/repo run_id=123456789"
}
```

#### Expected Response (Invalid Request)

```json
{
  "error": "Missing required field: owner"
}
```

### Testing Locally

You can also test locally using the GitHub client:

```python
from src.github.client import GitHubClient
from src.analyzers import WorkflowAnalyzer

# Set GITHUB_TOKEN environment variable
import os
os.environ['GITHUB_TOKEN'] = 'your-token'

client = GitHubClient()
analyzer = WorkflowAnalyzer()

workflow_run = client.get_workflow_run('owner', 'repo', 123456789)
jobs = client.get_workflow_run_jobs('owner', 'repo', 123456789)

analysis = analyzer.analyze(workflow_run, jobs)
print(analysis)
```

### Common Issues

#### 401 Unauthorized
- **Cause**: GitHub token is invalid or expired
- **Fix**: Update the token in SSM Parameter Store

#### 404 Not Found
- **Cause**: Workflow run ID doesn't exist or repository is private
- **Fix**: Verify the run ID and ensure token has access to the repository

#### 500 Internal Server Error
- **Cause**: Lambda function error
- **Fix**: Check CloudWatch Logs for details

### Viewing Logs

```bash
# View recent Lambda logs
aws logs tail /aws/lambda/deploymentor-dev --follow

# View logs for specific time range
aws logs tail /aws/lambda/deploymentor-dev --since 10m

# Filter for errors
aws logs tail /aws/lambda/deploymentor-dev --since 1h | grep ERROR
```

### Test Scenarios

1. **Valid failed workflow**: Should return analysis with error types and suggestions
2. **Valid successful workflow**: Should return `failed: false`
3. **Invalid run_id**: Should return 404 error
4. **Missing fields**: Should return 400 error
5. **Private repository**: Should return 404 if token lacks access

