#!/bin/bash
# Import existing Terraform resources if they exist
# This script checks if resources exist and imports them into Terraform state
# Must be run from the terraform directory

# Set ENVIRONMENT from first argument, default to prod
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
    # Use -var flag to prevent interactive prompts
    if terraform import -var="environment=${ENVIRONMENT}" "${resource_address}" "${resource_id}" 2>&1; then
        echo "  ✅ Imported: ${resource_address}"
        return 0
    else
        echo "  ⚠️  Not found or already exists: ${resource_address}"
        return 1
    fi
}

# Import Lambda Function
import_if_exists "module.lambda.aws_lambda_function.this" "${FUNCTION_NAME}" "Lambda Function" || true

# Import CloudWatch Log Groups
import_if_exists "module.lambda.aws_cloudwatch_log_group.lambda" "${LOG_GROUP_LAMBDA}" "Lambda Log Group" || true
import_if_exists "module.api_gateway.aws_cloudwatch_log_group.api" "${LOG_GROUP_API}" "API Gateway Log Group" || true

# Import IAM Roles
import_if_exists "module.lambda.aws_iam_role.lambda" "${ROLE_LAMBDA}" "Lambda IAM Role" || true
import_if_exists "module.github_oidc.aws_iam_role.github_actions" "${ROLE_GITHUB}" "GitHub OIDC Role" || true

# Import API Gateway resources
# Lambda permission for API Gateway
LAMBDA_PERMISSION_ID="${FUNCTION_NAME}/AllowExecutionFromAPIGateway"
import_if_exists "module.api_gateway.aws_lambda_permission.api_gateway" "${LAMBDA_PERMISSION_ID}" "Lambda Permission" || true

# Try to import API Gateway resources if API exists
# First, check if API is in state or try to get its ID
API_NAME="deploymentor-${ENVIRONMENT}"
if terraform state show "module.api_gateway.aws_apigatewayv2_api.this" >/dev/null 2>&1; then
    # API is in state, get its ID
    API_ID=$(terraform state show "module.api_gateway.aws_apigatewayv2_api.this" | grep -E "^id\s+=" | awk '{print $3}' | tr -d '"' || echo "")
elif command -v aws >/dev/null 2>&1; then
    # Try to get API ID from AWS
    API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId" --output text 2>/dev/null | head -1 || echo "")
fi

if [ -n "${API_ID}" ]; then
    echo "Found API ID: ${API_ID}, attempting to import dependent resources..."
    
    # Import API Gateway Integration
    # Integration ID format: {api_id}/{integration_id}
    # We need to find the integration ID first
    if command -v aws >/dev/null 2>&1; then
        INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id "${API_ID}" --query "Items[0].IntegrationId" --output text 2>/dev/null || echo "")
        if [ -n "${INTEGRATION_ID}" ] && [ "${INTEGRATION_ID}" != "None" ]; then
            import_if_exists "module.api_gateway.aws_apigatewayv2_integration.lambda" "${API_ID}/${INTEGRATION_ID}" "API Gateway Integration" || true
        fi
    fi
    
    # Import API Gateway Route
    # Route ID format: {api_id}/{route_id}
    if command -v aws >/dev/null 2>&1; then
        ROUTE_ID=$(aws apigatewayv2 get-routes --api-id "${API_ID}" --query "Items[?RouteKey=='\\$default'].RouteId" --output text 2>/dev/null | head -1 || echo "")
        if [ -n "${ROUTE_ID}" ] && [ "${ROUTE_ID}" != "None" ]; then
            import_if_exists "module.api_gateway.aws_apigatewayv2_route.default" "${API_ID}/${ROUTE_ID}" "API Gateway Route" || true
        fi
    fi
    
    # Import API Gateway Stage
    # Stage format: {api_id}/{stage_name}
    import_if_exists "module.api_gateway.aws_apigatewayv2_stage.default" "${API_ID}/\$default" "API Gateway Stage" || true
else
    echo "⚠️  API Gateway API not found in state or AWS, skipping dependent resource imports"
fi

echo ""
echo "✅ Import check complete!"

