"""
Main Lambda handler for DeployMentor API.

This is the entry point for all API Gateway requests.
"""

import json
import logging
from typing import Any, Dict

from src.analyzers import LogAnalyzer

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler function.

    Args:
        event: API Gateway HTTP API event
        context: Lambda context object

    Returns:
        API Gateway HTTP API response
    """
    # Log sanitized event (avoid logging sensitive headers/data)
    safe = {
        "path": event.get("path"),
        "httpMethod": event.get("httpMethod"),
        "requestId": (event.get("requestContext") or {}).get("requestId"),
    }
    logger.info("SANITIZED_REQUEST: %s", safe)

    # Extract HTTP method and path
    # API Gateway HTTP API v2 format
    request_context = event.get("requestContext", {})
    http_context = request_context.get("http", {})

    http_method = (
        event.get("httpMethod")
        or http_context.get("method")
        or request_context.get("httpMethod")
        or "GET"
    )

    # Path can be in multiple places for HTTP API v2
    path = (
        event.get("path")
        or http_context.get("path")
        or request_context.get("path")
        or event.get("rawPath")
        or "/"
    )

    logger.info(f"Extracted method: {http_method}, path: {path}")

    # Route handling
    if path == "/health" and http_method == "GET":
        return _health_check()

    if path == "/analyze" and http_method == "POST":
        return _analyze_logs(event)

    # Default 404 response
    return {
        "statusCode": 404,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(
            {"error": "Not Found", "message": f"No handler for {http_method} {path}"}
        ),
    }


def _health_check() -> Dict[str, Any]:
    """Health check endpoint."""
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({"status": "healthy", "service": "deploymentor", "version": "0.1.0"}),
    }


def _analyze_logs(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze CI/CD logs and return root cause analysis.

    Expected request body:
    {
        "source": "github_actions",
        "logs": "<string logs here>"
    }
    """
    try:
        # Parse request body
        body = event.get("body", "{}")
        if isinstance(body, str):
            body = json.loads(body)
        elif body is None:
            body = {}

        # Validate required fields
        source = body.get("source", "github_actions")
        logs = body.get("logs")

        if logs is None:
            return _error_response(400, "Missing required field: logs")

        if not isinstance(logs, str):
            return _error_response(400, "Field 'logs' must be a string")

        logger.info(f"Analyzing logs from source: {source}")

        # Initialize log analyzer
        analyzer = LogAnalyzer()

        # Analyze logs
        try:
            analysis = analyzer.analyze(logs, source)
        except Exception as e:
            logger.error(f"Error analyzing logs: {e}")
            return _error_response(500, f"Error analyzing logs: {str(e)}")

        # Return analysis result
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
            },
            "body": json.dumps(analysis),
        }

    except json.JSONDecodeError:
        return _error_response(400, "Invalid JSON in request body")
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return _error_response(500, f"Internal server error: {str(e)}")


def _error_response(status_code: int, message: str) -> Dict[str, Any]:
    """Create an error response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({"error": message}),
    }
