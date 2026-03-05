#!/bin/bash
# Script to test the POST /analyze endpoint

set -e

# Get API URL from Terraform output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT/terraform"
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null | sed 's|/$||')

if [ -z "$API_URL" ]; then
    echo "❌ Error: Could not get API URL from Terraform"
    echo "   Make sure you've deployed the infrastructure:"
    echo "   cd terraform && terraform apply -var=\"environment=prod\""
    exit 1
fi

echo "🔍 Testing POST /analyze endpoint"
echo "API URL: ${API_URL}"
echo ""

# Test 1: IAM Permission Error
echo "Test 1: IAM Permission Error"
echo "----------------------------"
curl -s -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: AccessDenied: User is not authorized to perform s3:GetObject"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 2: Module Not Found
echo "Test 2: Python Module Not Found"
echo "-------------------------------"
curl -s -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "ModuleNotFoundError: No module named requests"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 3: File Not Found
echo "Test 3: File Not Found"
echo "---------------------"
curl -s -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions",
    "logs": "Error: No such file or directory: /app/config.json"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 4: Missing logs (should return 400)
echo "Test 4: Missing Logs (Error Case)"
echo "---------------------------------"
curl -s -X POST ${API_URL}/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github_actions"
  }' | python3 -m json.tool
echo ""
echo ""

echo "✅ Tests complete!"

