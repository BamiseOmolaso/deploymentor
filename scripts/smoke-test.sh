#!/bin/bash
# Smoke test script for DeployMentor API
# Usage: ./scripts/smoke-test.sh <environment>
# Environment: dev, staging, or prod

set -e

ENVIRONMENT="${1:-prod}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "❌ Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

echo "🧪 Running smoke tests for $ENVIRONMENT environment..."
echo ""

# Get API URL from Terraform output
TERRAFORM_DIR="terraform/environments/$ENVIRONMENT"

if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "❌ Error: Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

echo "📋 Getting API URL from Terraform..."
cd "$TERRAFORM_DIR"
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
cd - > /dev/null

if [ -z "$API_URL" ]; then
  echo "❌ Error: Could not get API URL from Terraform output"
  echo "   Make sure Terraform has been applied for $ENVIRONMENT"
  exit 1
fi

echo "✅ API URL: $API_URL"
echo ""

# Test 1: Health check
echo "🔍 Test 1: Health check endpoint"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/health" || echo -e "\n000")
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -n -1)
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -n 1)

if [ "$HEALTH_CODE" = "200" ]; then
  echo "   ✅ Health check passed (200 OK)"
  echo "   Response: $HEALTH_BODY"
else
  echo "   ❌ Health check failed (HTTP $HEALTH_CODE)"
  echo "   Response: $HEALTH_BODY"
  exit 1
fi

echo ""

# Test 2: Analyze endpoint with known failed run ID
# Using a known failed run ID from the deploymentor repo
echo "🔍 Test 2: Analyze endpoint with failed workflow run"
FAILED_RUN_ID="22800439951"  # Known failed run from deploymentor repo

ANALYZE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -d "{\"owner\": \"BamiseOmolaso\", \"repo\": \"deploymentor\", \"run_id\": $FAILED_RUN_ID}" \
  || echo -e "\n000")

ANALYZE_BODY=$(echo "$ANALYZE_RESPONSE" | head -n -1)
ANALYZE_CODE=$(echo "$ANALYZE_RESPONSE" | tail -n 1)

if [ "$ANALYZE_CODE" != "200" ]; then
  echo "   ❌ Analyze endpoint failed (HTTP $ANALYZE_CODE)"
  echo "   Response: $ANALYZE_BODY"
  exit 1
fi

# Check if response contains "failed": true
if echo "$ANALYZE_BODY" | grep -q '"failed"\s*:\s*true'; then
  echo "   ✅ Analysis correctly identified failed workflow"
else
  echo "   ❌ Analysis did not identify workflow as failed"
  echo "   Response: $ANALYZE_BODY"
  exit 1
fi

# Check if error_message is not null
if echo "$ANALYZE_BODY" | grep -q '"error_message"\s*:\s*[^n][^u][^l][^l]'; then
  echo "   ✅ Error message is populated (not null)"
else
  echo "   ⚠️  Warning: error_message may be null"
  # This is a warning, not a failure, as some workflows may not have error messages
fi

echo ""

# Summary
echo "✅ All smoke tests passed for $ENVIRONMENT environment!"
echo ""
echo "📊 Summary:"
echo "   ✅ Health endpoint: Working"
echo "   ✅ Analyze endpoint: Working"
echo "   ✅ Error detection: Working"
echo ""

