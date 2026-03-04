#!/bin/bash
# Script to package Lambda function with dependencies
# Usage: ./scripts/package-lambda-with-deps.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$PROJECT_ROOT/lambda-package"
OUTPUT_FILE="$PROJECT_ROOT/lambda_function.zip"

echo "📦 Packaging Lambda function with dependencies..."
echo "Source: $PROJECT_ROOT/src"
echo "Output: $OUTPUT_FILE"

# Clean up previous package
rm -rf "$PACKAGE_DIR"
rm -f "$OUTPUT_FILE"

# Create package directory
mkdir -p "$PACKAGE_DIR"

# Copy source code
echo "Copying source code..."
cp -r "$PROJECT_ROOT/src" "$PACKAGE_DIR/"

# Install dependencies
echo "Installing dependencies..."
pip install -r "$PROJECT_ROOT/requirements.txt" -t "$PACKAGE_DIR" --no-cache-dir

# Create zip file
echo "Creating zip file..."
cd "$PACKAGE_DIR"
zip -r "$OUTPUT_FILE" . \
    -x "*.pyc" \
    -x "__pycache__/*" \
    -x "*.pyo" \
    -x "*.pyd" \
    -x ".DS_Store" \
    -x "*.dist-info/*" \
    -x "*.egg-info/*" \
    > /dev/null

# Clean up
cd "$PROJECT_ROOT"
rm -rf "$PACKAGE_DIR"

echo "✅ Lambda package created: $OUTPUT_FILE"
echo ""
echo "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"

