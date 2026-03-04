#!/bin/bash
# Script to test the /analyze endpoint
# Usage: ./scripts/test-analyze.sh OWNER REPO RUN_ID

set -e

# Get API URL from environment variable, Terraform output, or use default
if [ -z "$API_URL" ]; then
    if [ -f terraform/outputs.tf ] && command -v terraform > /dev/null 2>&1; then
        API_URL=$(cd terraform && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    fi
    if [ -z "$API_URL" ] && [ -f .env ]; then
        API_URL=$(grep API_GATEWAY_URL .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    fi
    API_URL="${API_URL:-https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com}"
fi

if [ $# -lt 3 ]; then
    echo "Usage: $0 OWNER REPO RUN_ID"
    echo ""
    echo "Example:"
    echo "  $0 octocat hello-world 123456789"
    echo ""
    echo "To find a workflow run ID:"
    echo "  1. Go to your GitHub repo → Actions tab"
    echo "  2. Click on a failed workflow run"
    echo "  3. Copy the run ID from the URL"
    exit 1
fi

OWNER=$1
REPO=$2
RUN_ID=$3

echo "🔍 Testing /analyze endpoint..."
echo "Owner: $OWNER"
echo "Repo: $REPO"
echo "Run ID: $RUN_ID"
echo ""

RESPONSE=$(curl -s -X POST "$API_URL/analyze" \
  -H "Content-Type: application/json" \
  -d "{
    \"owner\": \"$OWNER\",
    \"repo\": \"$REPO\",
    \"run_id\": $RUN_ID
  }")

echo "Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Check HTTP status
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/analyze" \
  -H "Content-Type: application/json" \
  -d "{
    \"owner\": \"$OWNER\",
    \"repo\": \"$REPO\",
    \"run_id\": $RUN_ID
  }")

echo "HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Success!"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  Workflow run not found. Check:"
    echo "   - Run ID is correct"
    echo "   - Repository is accessible"
    echo "   - GitHub token has permissions"
elif [ "$HTTP_CODE" = "400" ]; then
    echo "⚠️  Bad request. Check input parameters."
elif [ "$HTTP_CODE" = "500" ]; then
    echo "❌ Server error. Check CloudWatch logs:"
    echo "   aws logs tail /aws/lambda/deploymentor-dev --follow"
else
    echo "⚠️  Unexpected status code: $HTTP_CODE"
fi

