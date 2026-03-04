#!/bin/bash
# Daily health check script for DeployMentor
# Usage: ./scripts/health-check.sh

set -e

# Get API URL from environment variable, Terraform output, or use default placeholder
if [ -z "$API_URL" ]; then
    if [ -f terraform/outputs.tf ] && command -v terraform > /dev/null 2>&1; then
        API_URL=$(cd terraform && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    fi
    if [ -z "$API_URL" ] && [ -f .env ]; then
        API_URL=$(grep API_GATEWAY_URL .env | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    fi
    API_URL="${API_URL:-https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com}"
fi

echo "🔍 DeployMentor Health Check"
echo "============================"
echo ""

# Health check
echo "1. Checking health endpoint..."
if curl -sf "$API_URL/health" > /dev/null; then
    echo "   ✅ Health endpoint: OK"
    HEALTH_RESPONSE=$(curl -sf "$API_URL/health")
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "   ❌ Health endpoint: FAILED"
    exit 1
fi

echo ""

# Test analyze endpoint (optional - requires valid workflow)
if [ -n "$TEST_WORKFLOW_OWNER" ] && [ -n "$TEST_WORKFLOW_REPO" ] && [ -n "$TEST_WORKFLOW_RUN_ID" ]; then
    echo "2. Testing analyze endpoint..."
    ANALYZE_RESPONSE=$(curl -sf -X POST "$API_URL/analyze" \
        -H "Content-Type: application/json" \
        -d "{
            \"owner\": \"$TEST_WORKFLOW_OWNER\",
            \"repo\": \"$TEST_WORKFLOW_REPO\",
            \"run_id\": $TEST_WORKFLOW_RUN_ID
        }")
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Analyze endpoint: OK"
        ERROR_TYPES=$(echo "$ANALYZE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(', '.join(data.get('analysis', {}).get('error_types', [])) or 'none')" 2>/dev/null || echo "unknown")
        echo "   Error types detected: $ERROR_TYPES"
    else
        echo "   ❌ Analyze endpoint: FAILED"
        exit 1
    fi
else
    echo "2. Skipping analyze endpoint test (set TEST_WORKFLOW_OWNER, TEST_WORKFLOW_REPO, TEST_WORKFLOW_RUN_ID)"
fi

echo ""
echo "✅ Health check complete!"

