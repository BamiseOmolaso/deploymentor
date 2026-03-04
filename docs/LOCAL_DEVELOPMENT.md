# Local Development Guide

## Environment Variables

For local development, you can use a `.env` file to store your GitHub token.

### Setup

1. **Create `.env` file** (already created):
```bash
# .env file
GITHUB_TOKEN=ghp_your_token_here
AWS_ACCOUNT_ID=your_account_id_here
AWS_ROLE_ARN=arn:aws:iam::your_account_id:role/deploymentor-github-actions-role-dev
API_GATEWAY_URL=https://your-api-id.execute-api.us-east-1.amazonaws.com/
```

2. **Load environment variables**:

**Option A: Manual export**
```bash
export GITHUB_TOKEN=$(grep GITHUB_TOKEN .env | cut -d '=' -f2)
```

**Option B: Using the helper script**
```bash
source scripts/load-env.sh
```

**Option C: Using python-dotenv** (if installed)
```bash
pip install python-dotenv
# Then in Python:
from dotenv import load_dotenv
load_dotenv()
```

### Verify Setup

Test that your GitHub token is loaded:

```bash
# Load environment
source scripts/load-env.sh

# Test GitHub client
python -c "
import os
from src.github.client import GitHubClient
client = GitHubClient()
print('✅ GitHub client initialized successfully')
print(f'Token: {client.token[:10]}...')
"
```

### Running Tests Locally

```bash
# Activate virtual environment
source venv/bin/activate

# Load environment variables
source scripts/load-env.sh

# Run tests
pytest tests/ -v
```

### Running Lambda Handler Locally

You can test the Lambda handler locally:

```bash
# Load environment
source scripts/load-env.sh

# Test health endpoint
python -c "
from src.lambda_handler import handler
event = {
    'requestContext': {
        'http': {
            'method': 'GET',
            'path': '/health'
        }
    }
}
result = handler(event, None)
print(result['body'])
"
```

## Important Notes

### Security

- ✅ `.env` is already in `.gitignore` - your token won't be committed
- ✅ Never commit `.env` files to git
- ✅ Use `.env.example` as a template (without real values)

### For Production/Lambda

- The `.env` file is **only for local development**
- For Lambda, you **must** create the SSM parameter (see `docs/SSM_SETUP.md`)
- Lambda will automatically use SSM Parameter Store

### Environment Variable Priority

The GitHub client checks tokens in this order:
1. Explicit token parameter (if provided)
2. `GITHUB_TOKEN` environment variable (local dev)
3. SSM Parameter Store (Lambda/production)

## Troubleshooting

### Token not found

```bash
# Check if token is loaded
echo $GITHUB_TOKEN

# If empty, load environment
source scripts/load-env.sh

# Verify .env file exists and has correct format
cat .env
```

### Format Issues

Your `.env` file should look like:
```
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

**Don't use quotes:**
- ❌ `GITHUB_TOKEN="ghp_xxx"` (quotes included in value)
- ✅ `GITHUB_TOKEN=ghp_xxx` (no quotes)

## Next Steps

1. ✅ `.env` file created
2. ⏳ Load environment variables
3. ⏳ Test locally
4. ⏳ Create SSM parameter for Lambda (Step 9)
5. ⏳ Deploy infrastructure (Step 10)

