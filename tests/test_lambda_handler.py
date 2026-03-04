"""
Tests for Lambda handler.
"""

import json
from unittest.mock import patch

import pytest

from src.lambda_handler import handler


def test_health_endpoint():
    """Test health check endpoint."""
    event = {
        "requestContext": {
            "http": {
                "method": "GET",
                "path": "/health"
            }
        }
    }
    
    response = handler(event, None)
    
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["status"] == "healthy"
    assert body["service"] == "deploymentor"


def test_not_found():
    """Test 404 for unknown routes."""
    event = {
        "requestContext": {
            "http": {
                "method": "GET",
                "path": "/unknown"
            }
        }
    }
    
    response = handler(event, None)
    
    assert response["statusCode"] == 404
    body = json.loads(response["body"])
    assert "error" in body

