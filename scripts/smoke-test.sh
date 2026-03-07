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

# Get API key from SSM
echo "🔑 Fetching API key from SSM..."
API_KEY=$(aws ssm get-parameter \
  --name "/deploymentor/$ENVIRONMENT/api_key" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text 2>/dev/null || echo "")

if [ -z "$API_KEY" ]; then
  echo "❌ Error: Could not retrieve API key from SSM"
  echo "   Parameter path: /deploymentor/$ENVIRONMENT/api_key"
  echo "   Make sure the parameter exists and AWS credentials are configured"
  exit 1
fi

echo "✅ API key retrieved"
echo ""

# Test 1: Health check (no auth required)
echo "🔍 Test 1: Health check endpoint"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/health" || echo -e "\n000")
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -n 1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HEALTH_CODE" = "200" ]; then
  echo "   ✅ Health check passed (200 OK)"
  echo "   Response: $HEALTH_BODY"
else
  echo "   ❌ Health check failed (HTTP $HEALTH_CODE)"
  echo "   Response: $HEALTH_BODY"
  exit 1
fi

echo ""

# Test 2: Analyze endpoint without API key should return 401
echo "🔍 Test 2: Analyze endpoint without API key should be rejected"
FAILED_RUN_ID="22800439951"  # Known failed run from deploymentor repo

UNAUTH_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -d "{\"owner\": \"BamiseOmolaso\", \"repo\": \"deploymentor\", \"run_id\": $FAILED_RUN_ID}" \
  || echo -e "\n000")

UNAUTH_CODE=$(echo "$UNAUTH_RESPONSE" | tail -n 1)
UNAUTH_BODY=$(echo "$UNAUTH_RESPONSE" | sed '$d')

if [ "$UNAUTH_CODE" = "401" ] || [ "$UNAUTH_CODE" = "403" ]; then
  echo "   ✅ Unauthenticated request correctly rejected ($UNAUTH_CODE)"
else
  echo "   ❌ Unauthenticated request was not rejected (got $UNAUTH_CODE, expected 401/403)"
  echo "   Response: $UNAUTH_BODY"
  exit 1
fi

echo ""

# Test 3: Analyze endpoint with API key should succeed
echo "🔍 Test 3: Analyze endpoint with valid API key"
ANALYZE_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{\"owner\": \"BamiseOmolaso\", \"repo\": \"deploymentor\", \"run_id\": $FAILED_RUN_ID}" \
  || echo -e "\n000")

ANALYZE_CODE=$(echo "$ANALYZE_RESPONSE" | tail -n 1)
ANALYZE_BODY=$(echo "$ANALYZE_RESPONSE" | sed '$d')

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

# Check if error_message is populated
if echo "$ANALYZE_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); steps=d.get('analysis',{}).get('root_cause',{}).get('step_analyses',[]); msg=steps[0].get('error_message','') if steps else ''; sys.exit(0 if msg and msg!='None' and msg!='null' else 1)" 2>/dev/null; then
  echo "   ✅ Error message is populated"
else
  echo "   ⚠️  Warning: error_message may be null or empty"
  # This is a warning, not a failure, as some workflows may not have error messages
fi

echo ""

# Summary
echo "✅ All smoke tests passed for $ENVIRONMENT environment!"
echo ""
echo "📊 Summary:"
echo "   ✅ Health endpoint: Working"
echo "   ✅ Unauthenticated request rejected: Working"
echo "   ✅ Authenticated analyze: Working"
echo "   ✅ Error detection: Working"
echo ""
