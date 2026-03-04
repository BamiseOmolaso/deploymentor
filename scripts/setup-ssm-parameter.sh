#!/bin/bash
# Script to create SSM parameter for GitHub token
# Usage: ./scripts/setup-ssm-parameter.sh <github-token>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <github-token>"
    echo "Example: $0 ghp_xxxxxxxxxxxx"
    exit 1
fi

GITHUB_TOKEN="$1"
PARAMETER_NAME="/deploymentor/github/token"
REGION="${AWS_REGION:-us-east-1}"

echo "Creating SSM parameter: $PARAMETER_NAME"
echo "Region: $REGION"

aws ssm put-parameter \
    --name "$PARAMETER_NAME" \
    --value "$GITHUB_TOKEN" \
    --type "SecureString" \
    --region "$REGION" \
    --overwrite \
    --description "GitHub Personal Access Token for DeployMentor"

echo "✅ SSM parameter created successfully!"
echo ""
echo "To verify:"
echo "  aws ssm get-parameter --name $PARAMETER_NAME --with-decryption --region $REGION"

