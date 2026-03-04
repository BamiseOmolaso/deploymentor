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

# Create package directory with src structure
PACKAGE_DIR="$PROJECT_ROOT/lambda-package-temp"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy src directory maintaining structure
cp -r "$PROJECT_ROOT/src" "$PACKAGE_DIR/"

cd "$PACKAGE_DIR"

# Remove old zip if exists
rm -f "$OUTPUT_FILE"

# Create zip file with src/ directory structure
zip -r "$OUTPUT_FILE" . \
    -x "*.pyc" \
    -x "__pycache__/*" \
    -x "*.pyo" \
    -x "*.pyd" \
    -x ".DS_Store" \
    -x "*.git*"

# Clean up
cd "$PROJECT_ROOT"
rm -rf "$PACKAGE_DIR"

echo "✅ Lambda package created: $OUTPUT_FILE"
echo ""
echo "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"

