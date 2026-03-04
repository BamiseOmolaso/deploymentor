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
    # Try to get API ID from AWS, filtering by name to match only this environment's API
    API_ID=$(aws apigatewayv2 get-apis \
        --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
        --output text 2>/dev/null || echo "")
fi

# Check if API_ID is valid (not empty and not "None")
if [ -n "${API_ID}" ] && [ "${API_ID}" != "None" ] && [ "${API_ID}" != "null" ]; then
    echo "Found API ID: ${API_ID}, checking for dependent resources..."
    
    if command -v aws >/dev/null 2>&1; then
        # Import API Gateway Integration
        # Integration ID format: {api_id}/{integration_id}
        # Check if integration exists before importing
        INTEGRATION_EXISTS=$(aws apigatewayv2 get-integrations --api-id "${API_ID}" --query "Items[0].IntegrationId" --output text 2>/dev/null || echo "")
        if [ -n "${INTEGRATION_EXISTS}" ] && [ "${INTEGRATION_EXISTS}" != "None" ] && [ "${INTEGRATION_EXISTS}" != "null" ]; then
            import_if_exists "module.api_gateway.aws_apigatewayv2_integration.lambda" "${API_ID}/${INTEGRATION_EXISTS}" "API Gateway Integration" || true
        else
            echo "⏭️  Skipping: Integration does not exist yet for API ${API_ID}"
        fi
        
        # Import API Gateway Route
        # Route ID format: {api_id}/{route_id}
        # Check if route exists before importing
        ROUTE_EXISTS=$(aws apigatewayv2 get-routes --api-id "${API_ID}" --query "Items[?RouteKey=='\\$default'].RouteId | [0]" --output text 2>/dev/null || echo "")
        if [ -n "${ROUTE_EXISTS}" ] && [ "${ROUTE_EXISTS}" != "None" ] && [ "${ROUTE_EXISTS}" != "null" ]; then
            import_if_exists "module.api_gateway.aws_apigatewayv2_route.default" "${API_ID}/${ROUTE_EXISTS}" "API Gateway Route" || true
        else
            echo "⏭️  Skipping: \$default route does not exist yet for API ${API_ID}"
        fi
        
        # Import API Gateway Stage
        # Stage format: {api_id}/{stage_name}
        # Check if stage exists before importing
        STAGE_EXISTS=$(aws apigatewayv2 get-stage \
            --api-id "${API_ID}" \
            --stage-name '$default' \
            --query "StageName" \
            --output text 2>/dev/null || echo "")
        if [ -n "${STAGE_EXISTS}" ] && [ "${STAGE_EXISTS}" != "None" ] && [ "${STAGE_EXISTS}" != "null" ]; then
            import_if_exists "module.api_gateway.aws_apigatewayv2_stage.default" "${API_ID}/\$default" "API Gateway Stage" || true
        else
            echo "⏭️  Skipping: \$default stage does not exist yet for API ${API_ID}"
        fi
    else
        echo "⚠️  AWS CLI not available, skipping API Gateway dependent resource imports"
    fi
else
    echo "⚠️  API Gateway API '${API_NAME}' not found in state or AWS, skipping dependent resource imports"
fi

echo ""
echo "✅ Import check complete!"

