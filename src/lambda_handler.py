"""
Main Lambda handler for DeployMentor API.

This is the entry point for all API Gateway requests.
"""

import json
import logging
import os
from typing import Any, Dict, Optional

from src.analyzers import LogAnalyzer, WorkflowAnalyzer
from src.github.client import GitHubClient
from src.utils.ssm import get_parameter

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
    # Check if we have enough time to process (guard against timeout)
    if context and hasattr(context, "get_remaining_time_in_millis"):
        remaining_ms = context.get_remaining_time_in_millis()
        if remaining_ms < 5000:  # Less than 5 seconds remaining
            logger.warning(f"Insufficient time remaining: {remaining_ms}ms")
            return {
                "statusCode": 503,
                "headers": {
                    "Content-Type": "application/json",
                },
                "body": json.dumps(
                    {
                        "error": "Insufficient time remaining to process request",
                        "message": (
                            "Request would exceed Lambda timeout. "
                            "Try with a smaller workflow run or contact support."
                        ),
                    }
                ),
            }

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

    # Normalize path: handle double slashes from API Gateway trailing slash
    # e.g., "//health" -> "/health", "//analyze" -> "/analyze"
    if path.startswith("//"):
        path = "/" + path.lstrip("/")
    elif path != "/":
        path = "/" + path.strip("/")

    logger.info(f"Extracted method: {http_method}, path: {path}")

    # Route handling
    if path == "/health" and http_method == "GET":
        return _health_check()

    if path == "/analyze" and http_method == "POST":
        # Validate API key for /analyze endpoint
        api_key_error = _validate_api_key(event)
        if api_key_error:
            return api_key_error
        return _analyze(event)

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


def _validate_api_key(event: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Validate API key from x-api-key header for /analyze endpoint.

    Returns:
        Error response if validation fails, None if valid
    """
    # Get API key from SSM parameter path (if configured)
    api_key_param = os.getenv("API_KEY_SSM_PARAM")
    if not api_key_param:
        # If no API key configured, allow access (backward compatibility)
        logger.warning("API_KEY_SSM_PARAM not set, skipping API key validation")
        return None

    # Get expected API key from SSM
    try:
        expected_key = get_parameter(api_key_param, decrypt=True)
        if not expected_key:
            logger.warning(f"API key not found in SSM at {api_key_param}, allowing request")
            return None
    except Exception as e:
        logger.error(f"Error retrieving API key from SSM: {e}")
        # Fail open for now to avoid breaking existing deployments
        return None

    # Extract API key from headers
    headers = event.get("headers", {}) or {}
    # Headers can be dict or case-insensitive dict, normalize to lowercase
    headers_lower = {k.lower(): v for k, v in headers.items()}
    provided_key = headers_lower.get("x-api-key") or headers_lower.get("x-apikey")

    if not provided_key:
        return {
            "statusCode": 401,
            "headers": {
                "Content-Type": "application/json",
            },
            "body": json.dumps(
                {
                    "error": "Unauthorized",
                    "message": (
                        "Missing x-api-key header. "
                        "API key is required for /analyze endpoint."
                    ),
                }
            ),
        }

    if provided_key != expected_key:
        logger.warning("Invalid API key provided")
        return {
            "statusCode": 403,
            "headers": {
                "Content-Type": "application/json",
            },
            "body": json.dumps(
                {
                    "error": "Forbidden",
                    "message": "Invalid API key.",
                }
            ),
        }

    return None


def _health_check() -> Dict[str, Any]:
    """Health check endpoint."""
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({"status": "healthy", "service": "deploymentor", "version": "0.1.0"}),
    }


def _analyze(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze CI/CD failures - supports both GitHub run_id and direct logs.

    Request body formats:
    1. GitHub run_id: {"owner": "...", "repo": "...", "run_id": 123}
    2. Direct logs: {"source": "github_actions", "logs": "<string>"}
    """
    try:
        # Parse request body
        body = event.get("body", "{}")
        if isinstance(body, str):
            body = json.loads(body)
        elif body is None:
            body = {}

        # Detect request format - run_id flow takes priority
        if all(k in body for k in ("owner", "repo", "run_id")):
            return _analyze_workflow(body["owner"], body["repo"], body["run_id"])

        # Fall back to direct log analysis
        return _analyze_logs(body)

    except json.JSONDecodeError:
        return _error_response(400, "Invalid JSON in request body")
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return _error_response(500, f"Internal server error: {str(e)}")


def _analyze_workflow(owner: str, repo: str, run_id: Any) -> Dict[str, Any]:
    """
    Analyze a GitHub Actions workflow run using GitHub API.

    Args:
        owner: Repository owner (username or org)
        repo: Repository name
        run_id: Workflow run ID (will be converted to int)

    Returns:
        API Gateway response with analysis
    """
    try:
        # Validate run_id is an integer
        try:
            run_id = int(run_id)
        except (ValueError, TypeError):
            return _error_response(400, "run_id must be an integer")

        logger.info(f"Analyzing workflow: {owner}/{repo} run_id={run_id}")

        # Initialize GitHub client and analyzer
        github_client = GitHubClient()
        analyzer = WorkflowAnalyzer()

        # Fetch workflow data
        try:
            workflow_run = github_client.get_workflow_run(owner, repo, run_id)
            jobs = github_client.get_workflow_run_jobs(owner, repo, run_id)
        except Exception as e:
            logger.error(f"Error fetching workflow data: {e}")
            error_msg = str(e)
            if "404" in error_msg or "Not Found" in error_msg:
                return _error_response(
                    404, f"Workflow run not found: {owner}/{repo} run_id={run_id}"
                )
            return _error_response(500, f"Error fetching workflow data: {error_msg}")

        # Fetch and parse logs
        try:
            logger.info("Fetching logs for run_id=%s", run_id)
            raw_logs = github_client.get_workflow_run_logs(owner, repo, run_id)
            logger.info("Raw logs fetched: %s bytes", len(raw_logs) if raw_logs else 0)
            parsed_logs = github_client.parse_logs_zip(raw_logs)
            logger.info("Parsed log files: %s", list(parsed_logs.keys()))
        except Exception as e:
            logger.warning("Log fetching failed: %s", str(e))
            parsed_logs = {}

        # Analyze workflow
        try:
            analysis = analyzer.analyze(workflow_run, jobs, parsed_logs)
        except Exception as e:
            logger.error(f"Error analyzing workflow: {e}")
            return _error_response(500, f"Error analyzing workflow: {str(e)}")

        # Return analysis result
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
            },
            "body": json.dumps(analysis),
        }

    except Exception as e:
        logger.error(f"Unexpected error in workflow analysis: {e}", exc_info=True)
        return _error_response(500, f"Internal server error: {str(e)}")


def _analyze_logs(body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze CI/CD logs directly and return root cause analysis.

    Expected request body:
    {
        "source": "github_actions",
        "logs": "<string logs here>"
    }
    """
    try:
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

    except Exception as e:
        logger.error(f"Unexpected error in log analysis: {e}", exc_info=True)
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
