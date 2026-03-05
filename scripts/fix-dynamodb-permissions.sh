#!/bin/bash
# Script to fix DynamoDB permissions for GitHub Actions IAM role
# This patches the role directly via AWS CLI to unblock CI/CD
# The Terraform code will keep these permissions in sync on next apply

set -e

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Error: Could not get AWS account ID. Make sure AWS CLI is configured."
    exit 1
fi

REGION="us-east-1"
ROLE_NAME="deploymentor-github-actions-role-dev"
POLICY_NAME="deploymentor-dynamodb-state-lock"
TABLE_NAME="deploymentor-terraform-locks"

echo "🔧 Fixing DynamoDB permissions for GitHub Actions IAM role"
echo "   Role: $ROLE_NAME"
echo "   Table: $TABLE_NAME"
echo "   Account: $ACCOUNT_ID"
echo "   Region: $REGION"
echo ""

# Check if role exists
if ! aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
    echo "❌ Error: Role $ROLE_NAME does not exist"
    echo "   Make sure the role has been created first"
    exit 1
fi

# Apply inline policy
echo "📝 Applying DynamoDB permissions..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": [
        \"dynamodb:GetItem\",
        \"dynamodb:PutItem\",
        \"dynamodb:DeleteItem\"
      ],
      \"Resource\": \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}\"
    }]
  }"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ DynamoDB permissions applied to $ROLE_NAME"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Run 'terraform apply' to sync Terraform state with this change"
    echo "   2. The Terraform code already includes these permissions"
    echo "   3. Future applies will keep the permissions in sync"
else
    echo ""
    echo "❌ Error: Failed to apply permissions"
    exit 1
fi

