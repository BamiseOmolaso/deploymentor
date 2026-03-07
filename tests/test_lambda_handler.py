"""
Tests for Lambda handler.

Test PR to verify CI auto-triggers on test file changes.
"""

import json

from src.lambda_handler import handler


def test_health_endpoint():
    """Test health check endpoint."""
    event = {"requestContext": {"http": {"method": "GET", "path": "/health"}}}

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["status"] == "healthy"
    assert body["service"] == "deploymentor"


def test_not_found():
    """Test 404 for unknown routes."""
    event = {"requestContext": {"http": {"method": "GET", "path": "/unknown"}}}

    response = handler(event, None)

    assert response["statusCode"] == 404
    body = json.loads(response["body"])
    assert "error" in body


def test_analyze_logs_success():
    """Test POST /analyze with valid logs."""
    logs_content = "Error: AccessDenied: User is not authorized to perform s3:GetObject"
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/analyze"}},
        "body": json.dumps({"source": "github_actions", "logs": logs_content}),
    }

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert "summary" in body
    assert "probable_cause" in body
    assert "fix_steps" in body
    assert "confidence" in body
    assert isinstance(body["fix_steps"], list)
    assert 0.0 <= body["confidence"] <= 1.0
    assert "IAM" in body["summary"] or "permission" in body["summary"].lower()


def test_analyze_logs_missing_logs():
    """Test POST /analyze with missing logs field."""
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/analyze"}},
        "body": json.dumps({"source": "github_actions"}),
    }

    response = handler(event, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "error" in body
    assert "logs" in body["error"].lower()


def test_analyze_logs_empty_logs():
    """Test POST /analyze with empty logs."""
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/analyze"}},
        "body": json.dumps({"source": "github_actions", "logs": ""}),
    }

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["confidence"] == 0.0
    assert "No logs" in body["summary"]


def test_analyze_logs_module_not_found():
    """Test POST /analyze with ModuleNotFoundError."""
    logs_content = "ModuleNotFoundError: No module named 'requests'"
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/analyze"}},
        "body": json.dumps({"source": "github_actions", "logs": logs_content}),
    }

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert "Python" in body["summary"] or "module" in body["summary"].lower()
    assert body["confidence"] > 0.5


def test_analyze_logs_file_not_found():
    """Test POST /analyze with file not found error."""
    logs_content = "Error: No such file or directory: /app/config.json"
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/analyze"}},
        "body": json.dumps({"source": "github_actions", "logs": logs_content}),
    }

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert "file" in body["summary"].lower() or "directory" in body["summary"].lower()
    assert body["confidence"] > 0.5


def test_analyze_logs_invalid_json():
    """Test POST /analyze with invalid JSON."""
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/analyze"}},
        "body": "invalid json{",
    }

    response = handler(event, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "error" in body
    assert "JSON" in body["error"]


def test_health_with_double_slash():
    """Test GET //health with double slash (from API Gateway trailing slash)."""
    event = {"requestContext": {"http": {"method": "GET", "path": "//health"}}}

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["status"] == "healthy"
    assert body["service"] == "deploymentor"


def test_analyze_with_double_slash():
    """Test POST //analyze with double slash (from API Gateway trailing slash)."""
    logs_content = "Error: AccessDenied: User is not authorized to perform s3:GetObject"
    event = {
        "requestContext": {"http": {"method": "POST", "path": "//analyze"}},
        "body": json.dumps({"source": "github_actions", "logs": logs_content}),
    }

    response = handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert "summary" in body
    assert "probable_cause" in body
    assert "fix_steps" in body
    assert "confidence" in body
