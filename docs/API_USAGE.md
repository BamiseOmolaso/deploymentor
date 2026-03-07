# API Usage Guide

## Base URL

**Development**: Get from `terraform output api_gateway_url` or set `API_GATEWAY_URL` environment variable

**Example**: `https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com`

## Endpoints

### Health Check

Check if the API is running and healthy.

**Endpoint**: `GET /health`

**Request**:
```bash
# Get API URL from Terraform output or use environment variable
API_URL=$(terraform output -raw api_gateway_url)
curl $API_URL/health

# Or set API_GATEWAY_URL in .env and use:
curl ${API_GATEWAY_URL:-https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com}/health
```

**Response** (200 OK):
```json
{
  "status": "healthy",
  "service": "deploymentor",
  "version": "0.1.0"
}
```

---

### Analyze Workflow

Analyze a failed GitHub Actions workflow run to identify root causes and get suggestions.

**Endpoint**: `POST /analyze`

**Request Body**:
```json
{
  "owner": "BamiseOmolaso",
  "repo": "cloudportfoliowebsite",
  "run_id": 19727651809
}
```

**Request**:
```bash
# Get API URL from Terraform output or use environment variable
API_URL=$(terraform output -raw api_gateway_url)
curl -X POST $API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "BamiseOmolaso",
    "repo": "cloudportfoliowebsite",
    "run_id": 19727651809
  }'
```

**Response** (200 OK):
```json
{
  "workflow_id": 19727651809,
  "workflow_name": "CI Pipeline",
  "status": "completed",
  "conclusion": "failure",
  "failed_jobs_count": 1,
  "analysis": {
    "failed": true,
    "root_cause": {
      "job_id": 56522012971,
      "job_name": "Validate Terraform",
      "conclusion": "failure",
      "status": "completed",
      "started_at": "2025-11-27T06:47:29Z",
      "completed_at": "2025-11-27T06:47:38Z",
      "failed_steps_count": 1,
      "total_steps_count": 12,
      "error_type": "terraform",
      "step_analyses": [
        {
          "step_name": "Validate Dev Environment",
          "conclusion": "failure",
          "status": "completed",
          "number": 6,
          "is_failed": true,
          "error_type": null,
          "error_message": null
        }
      ],
      "has_step_details": true
    },
    "error_types": ["terraform"],
    "job_analyses": [...],
    "suggestions": [
      "Terraform validation or execution failed. Check Terraform configuration files for syntax errors or missing resources.",
      "Review Terraform plan output for detailed error messages. Common issues include: invalid resource configurations, missing variables, or state conflicts."
    ]
  }
}
```

**Error Responses**:

**400 Bad Request** - Missing required field:
```json
{
  "error": "Missing required field: owner"
}
```

**400 Bad Request** - Invalid run_id:
```json
{
  "error": "run_id must be an integer"
}
```

**404 Not Found** - Workflow run not found:
```json
{
  "error": "Workflow run not found: owner/repo run_id=123456789"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Error fetching workflow data: ..."
}
```

---

## Error Types

The analyzer detects the following error types:

- **terraform**: Terraform validation or execution failures
- **timeout**: Workflow or step timeouts
- **dependency**: Dependency installation failures (npm, pip, etc.)
- **syntax**: Syntax errors in code or configuration
- **permission**: Permission denied errors (401, 403)
- **network**: Network connectivity issues
- **resource**: Resource limitations (memory, disk space)
- **configuration**: Configuration errors (missing env vars, invalid config)

---

## Examples

### Example 1: Analyze Failed Terraform Workflow

```bash
# Get API URL from Terraform output or use environment variable
API_URL=$(terraform output -raw api_gateway_url)
curl -X POST $API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "BamiseOmolaso",
    "repo": "cloudportfoliowebsite",
    "run_id": 19727651809
  }' | jq '.analysis.error_types'
```

**Output**:
```json
["terraform"]
```

### Example 2: Get Root Cause

```bash
# Get API URL from Terraform output or use environment variable
API_URL=$(terraform output -raw api_gateway_url)
curl -X POST $API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "BamiseOmolaso",
    "repo": "cloudportfoliowebsite",
    "run_id": 19727651809
  }' | jq '.analysis.root_cause.job_name'
```

**Output**:
```json
"Validate Terraform"
```

### Example 3: Get Suggestions

```bash
# Get API URL from Terraform output or use environment variable
API_URL=$(terraform output -raw api_gateway_url)
curl -X POST $API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "BamiseOmolaso",
    "repo": "cloudportfoliowebsite",
    "run_id": 19727651809
  }' | jq '.analysis.suggestions'
```

**Output**:
```json
[
  "Terraform validation or execution failed. Check Terraform configuration files for syntax errors or missing resources.",
  "Review Terraform plan output for detailed error messages. Common issues include: invalid resource configurations, missing variables, or state conflicts."
]
```

---

## Rate Limits

Currently, there are no rate limits enforced. However, please use the API responsibly.

---

## Authentication

The API currently does not require authentication. This may change in future versions.

---

## Finding Workflow Run IDs

### From GitHub Web UI

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Find a failed workflow run
4. Click on the workflow run
5. Copy the run ID from the URL:
   ```
   https://github.com/OWNER/REPO/actions/runs/RUN_ID
   ```

### Using GitHub CLI

```bash
# List recent workflow runs
gh run list --limit 10

# Get details of a specific run
gh run view RUN_ID
```

### Using GitHub API

```bash
# List workflow runs
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/runs

# Find failed runs
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/actions/runs?status=failure
```

---

## Troubleshooting

### "No handler for POST //analyze" or "No handler for GET //health"

**Problem**: Your API URL has a trailing slash, and appending the path creates a double slash.

**Solution**: The handler now normalizes paths automatically, so this should work. If you still see this error:
- Strip the trailing slash from the base URL before appending the path
- Example: Use `https://api.example.com/analyze` instead of `https://api.example.com//analyze`
- Or use the exact URL from Terraform output (it will work with or without trailing slash)

### "Workflow run not found"

- Verify the run ID is correct
- Ensure the repository is accessible
- Check that the GitHub token has permissions

### "Missing required field"

- Ensure all required fields are provided: `owner`, `repo`, `run_id`
- Check JSON syntax is valid

### "run_id must be an integer"

- Ensure `run_id` is a number, not a string
- Remove quotes around the run_id value

### Internal Server Error

- Check CloudWatch Logs for details
- Verify GitHub token is valid
- Check SSM parameter exists and Lambda has read permissions

---

## Testing Script

Use the provided test script:

```bash
./scripts/test-analyze.sh OWNER REPO RUN_ID
```

**Example**:
```bash
./scripts/test-analyze.sh BamiseOmolaso cloudportfoliowebsite 19727651809
```

