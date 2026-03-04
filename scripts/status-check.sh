#!/bin/bash
# Quick status check script for DeployMentor infrastructure
# Usage: ./scripts/status-check.sh

set -e

echo "📊 DeployMentor Status Check"
echo "============================"
echo ""

# Terraform outputs
echo "1. Infrastructure Status:"
cd terraform 2>/dev/null || { echo "   ⚠️  Terraform directory not found"; exit 1; }

if terraform output api_gateway_url > /dev/null 2>&1; then
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
    echo "   ✅ API Gateway URL: $API_URL"
else
    echo "   ⚠️  Terraform outputs not available (run terraform apply)"
fi

if terraform output github_actions_role_arn > /dev/null 2>&1; then
    ROLE_ARN=$(terraform output -raw github_actions_role_arn 2>/dev/null)
    echo "   ✅ GitHub Actions Role: $ROLE_ARN"
else
    echo "   ⚠️  GitHub OIDC role not deployed yet"
fi

echo ""

# Lambda status
echo "2. Lambda Function Status:"
LAMBDA_NAME="deploymentor-dev"
if aws lambda get-function --function-name "$LAMBDA_NAME" > /dev/null 2>&1; then
    aws lambda get-function-configuration --function-name "$LAMBDA_NAME" \
        --query '[FunctionName,LastUpdateStatus,Runtime,Handler,MemorySize,Timeout]' \
        --output table 2>/dev/null || echo "   ⚠️  Could not fetch Lambda status"
else
    echo "   ⚠️  Lambda function not found"
fi

echo ""

# API Gateway status
echo "3. API Gateway Status:"
# Get API ID from Terraform output or environment
if command -v terraform > /dev/null 2>&1 && [ -f terraform/outputs.tf ]; then
    API_URL=$(cd terraform && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    if [ -n "$API_URL" ]; then
        API_ID=$(echo "$API_URL" | cut -d'/' -f3 | cut -d'.' -f1)
    fi
fi
API_ID="${API_ID:-YOUR_API_ID}"
if aws apigatewayv2 get-api --api-id "$API_ID" > /dev/null 2>&1; then
    aws apigatewayv2 get-api --api-id "$API_ID" \
        --query '[Name,ProtocolType,ApiEndpoint]' \
        --output table 2>/dev/null || echo "   ⚠️  Could not fetch API Gateway status"
else
    echo "   ⚠️  API Gateway not found"
fi

echo ""

# Recent logs
echo "4. Recent Logs (last 10 minutes):"
aws logs tail /aws/lambda/deploymentor-dev --since 10m --format short 2>/dev/null | tail -5 || echo "   ⚠️  Could not fetch logs"

echo ""
echo "✅ Status check complete!"

