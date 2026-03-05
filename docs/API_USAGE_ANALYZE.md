# Using the POST /analyze Endpoint

The `/analyze` endpoint analyzes CI/CD logs and provides root cause analysis with actionable fix steps.

## Quick Start

### 1. Get Your API URL

```bash
cd terraform
terraform output api_gateway_url
```

**Example output:** `https://xxxxx.execute-api.us-east-1.amazonaws.com`

### 2. Send Logs for Analysis

```bash
API_URL="https://your-api-id.execute-api.us-east-1.amazonaws.com"

curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: AccessDenied: User is not authorized to perform s3:GetObject"
  }'
```

## Request Format

```json
{
  "source": "github_actions",
  "logs": "<your log content as a string>"
}
```

**Fields:**
- `source` (optional, default: "github_actions"): Source of the logs (e.g., "github_actions", "gitlab_ci", "jenkins")
- `logs` (required): The log content as a string

## Response Format

```json
{
  "summary": "IAM permissions issue detected",
  "probable_cause": "The service account or IAM role lacks required permissions",
  "fix_steps": [
    "Check IAM policies attached to your role/service account",
    "Verify the specific permission needed (check error message)",
    "Add the missing permission to your IAM policy",
    "Wait a few minutes for IAM changes to propagate"
  ],
  "confidence": 0.9
}
```

**Fields:**
- `summary`: Brief summary of the issue
- `probable_cause`: Likely root cause explanation
- `fix_steps`: Array of actionable steps to fix the issue
- `confidence`: Confidence score (0.0 to 1.0)

## Example Use Cases

### 1. IAM Permission Error

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: AccessDenied: User is not authorized to perform s3:GetObject on resource arn:aws:s3:::my-bucket/file.txt"
  }'
```

**Expected Response:**
```json
{
  "summary": "IAM permissions issue detected",
  "probable_cause": "The service account or IAM role lacks required permissions",
  "fix_steps": [
    "Check IAM policies attached to your role/service account",
    "Verify the specific permission needed (check error message)",
    "Add the missing permission to your IAM policy",
    "Wait a few minutes for IAM changes to propagate"
  ],
  "confidence": 0.9
}
```

### 2. Python Module Not Found

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "ModuleNotFoundError: No module named 'requests'"
  }'
```

**Expected Response:**
```json
{
  "summary": "Python module/package not found",
  "probable_cause": "Missing Python dependency or incorrect environment",
  "fix_steps": [
    "Check if the module is listed in requirements.txt",
    "Verify your virtual environment is activated",
    "Run 'pip install -r requirements.txt'",
    "Check Python version compatibility"
  ],
  "confidence": 0.9
}
```

### 3. File Not Found

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: No such file or directory: /app/config.json"
  }'
```

**Expected Response:**
```json
{
  "summary": "File or directory not found",
  "probable_cause": "Missing file or incorrect path in build context",
  "fix_steps": [
    "Verify the file path is correct",
    "Check if the file exists in your repository",
    "Ensure the file is included in your build context",
    "Verify working directory in your CI/CD configuration"
  ],
  "confidence": 0.85
}
```

### 4. Terraform Backend Error

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: Error loading backend: Backend configuration changed"
  }'
```

**Expected Response:**
```json
{
  "summary": "Terraform backend configuration issue",
  "probable_cause": "Backend configuration error or state lock",
  "fix_steps": [
    "Verify backend configuration in terraform block",
    "Check if S3 bucket/DynamoDB table exists",
    "If state is locked, check for other running Terraform processes",
    "Verify AWS credentials have access to backend resources"
  ],
  "confidence": 0.85
}
```

### 5. Docker Build Failure

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: docker build failed: COPY failed: file not found in build context"
  }'
```

**Expected Response:**
```json
{
  "summary": "Docker build failure",
  "probable_cause": "Dockerfile error or build context issue",
  "fix_steps": [
    "Check Dockerfile syntax and commands",
    "Verify all files referenced in Dockerfile exist",
    "Check build context includes required files",
    "Review Docker build logs for specific error"
  ],
  "confidence": 0.8
}
```

## Using with Real GitHub Actions Logs

If you have a failed GitHub Actions workflow, you can copy the logs and analyze them:

```bash
# Copy logs from GitHub Actions UI
LOGS="$(cat your-failed-workflow-logs.txt)"

curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"github_actions\",
    \"logs\": \"${LOGS}\"
  }"
```

## Error Responses

### Missing Logs Field

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{"source": "github_actions"}'
```

**Response (400):**
```json
{
  "error": "Missing required field: logs"
}
```

### Invalid JSON

```bash
curl -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d 'invalid json'
```

**Response (400):**
```json
{
  "error": "Invalid JSON in request body"
}
```

## Using with Python

```python
import requests
import json

API_URL = "https://your-api-id.execute-api.us-east-1.amazonaws.com"

# Analyze logs
response = requests.post(
    f"{API_URL}/analyze",
    json={
        "source": "github_actions",
        "logs": "Error: AccessDenied: User is not authorized"
    }
)

analysis = response.json()
print(f"Summary: {analysis['summary']}")
print(f"Confidence: {analysis['confidence']}")
print("\nFix Steps:")
for step in analysis['fix_steps']:
    print(f"  - {step}")
```

## Using with JavaScript/Node.js

```javascript
const API_URL = 'https://your-api-id.execute-api.us-east-1.amazonaws.com';

async function analyzeLogs(logs) {
  const response = await fetch(`${API_URL}/analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      source: 'github_actions',
      logs: logs,
    }),
  });

  const analysis = await response.json();
  console.log('Summary:', analysis.summary);
  console.log('Confidence:', analysis.confidence);
  console.log('\nFix Steps:');
  analysis.fix_steps.forEach(step => console.log(`  - ${step}`));
  
  return analysis;
}

// Usage
analyzeLogs('Error: AccessDenied: User is not authorized');
```

## Supported Error Types

The analyzer recognizes these common CI/CD error patterns:

1. **IAM Permissions** - AccessDenied, unauthorized, permission denied
2. **File Not Found** - No such file or directory, file not found
3. **Python Module** - ModuleNotFoundError, ImportError
4. **Terraform Backend** - Backend configuration errors, state locks
5. **Docker Build** - Docker build failures, Dockerfile errors
6. **Timeout** - Operation timed out, execution time limit
7. **Network** - Connection errors, DNS failures

## Tips

1. **Include full error messages**: More context in logs = better analysis
2. **Include stack traces**: Stack traces help identify the exact failure point
3. **Include relevant context**: Include surrounding log lines for better context
4. **Check confidence score**: Higher confidence (0.8+) means more reliable analysis

## Troubleshooting

### Getting "Internal Server Error"

- Check Lambda logs: `aws logs tail "/aws/lambda/deploymentor-prod" --since 10m`
- Verify API Gateway is configured correctly
- Ensure Lambda function is deployed with latest code

### Analysis seems incorrect

- The analyzer uses pattern matching, not AI
- For complex issues, review the logs manually
- Confidence score indicates reliability (lower = less certain)

---

**Need help?** See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) or check the Lambda logs.

