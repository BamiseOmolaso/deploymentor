#!/bin/bash
# Import existing Terraform resources if they exist
# This script checks if resources exist and imports them into Terraform state

set -e

ENVIRONMENT="${1:-prod}"
FUNCTION_NAME="deploymentor-${ENVIRONMENT}"
LOG_GROUP_LAMBDA="/aws/lambda/${FUNCTION_NAME}"
LOG_GROUP_API="/aws/apigateway/deploymentor-${ENVIRONMENT}"
ROLE_LAMBDA="${FUNCTION_NAME}-execution-role"
ROLE_GITHUB="deploymentor-github-actions-role-${ENVIRONMENT}"

echo "🔍 Checking for existing resources..."

# Function to import resource if it exists
import_if_exists() {
    local resource_address=$1
    local resource_id=$2
    local resource_type=$3
    
    echo "Checking ${resource_type}..."
    if terraform state show "${resource_address}" >/dev/null 2>&1; then
        echo "  ✅ Already in state: ${resource_address}"
        return 0
    fi
    
    echo "  Attempting to import: ${resource_address}..."
    if terraform import "${resource_address}" "${resource_id}" 2>/dev/null; then
        echo "  ✅ Imported: ${resource_address}"
        return 0
    else
        echo "  ⚠️  Not found or already exists: ${resource_address}"
        return 1
    fi
}

# Import CloudWatch Log Groups
import_if_exists "module.lambda.aws_cloudwatch_log_group.lambda" "${LOG_GROUP_LAMBDA}" "Lambda Log Group" || true
import_if_exists "module.api_gateway.aws_cloudwatch_log_group.api" "${LOG_GROUP_API}" "API Gateway Log Group" || true

# Import IAM Roles
import_if_exists "module.lambda.aws_iam_role.lambda" "${ROLE_LAMBDA}" "Lambda IAM Role" || true
import_if_exists "module.github_oidc.aws_iam_role.github_actions" "${ROLE_GITHUB}" "GitHub OIDC Role" || true

echo ""
echo "✅ Import check complete!"

