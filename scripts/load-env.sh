#!/bin/bash
# Helper script to load .env file for local development
# Usage: source scripts/load-env.sh

if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
    echo "✅ Environment variables loaded"
else
    echo "⚠️  .env file not found"
    echo "   Create .env file with GITHUB_TOKEN=your_token"
fi

