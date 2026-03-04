#!/bin/bash
# Script to package Lambda function for deployment
# Usage: ./scripts/package-lambda.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$PROJECT_ROOT/lambda_function.zip"

echo "📦 Packaging Lambda function..."
echo "Source: $PROJECT_ROOT/src"
echo "Output: $OUTPUT_FILE"

cd "$PROJECT_ROOT/src"

# Remove old zip if exists
rm -f "$OUTPUT_FILE"

# Create zip file
zip -r "$OUTPUT_FILE" . \
    -x "*.pyc" \
    -x "__pycache__/*" \
    -x "*.pyo" \
    -x "*.pyd" \
    -x ".DS_Store" \
    -x "*.git*"

echo "✅ Lambda package created: $OUTPUT_FILE"
echo ""
echo "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"

