"""
Main Lambda handler for DeployMentor API.

This is the entry point for all API Gateway requests.
"""

import json
import logging
from typing import Any, Dict

from src.analyzers import WorkflowAnalyzer
from src.github.client import GitHubClient

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
    logger.info(f"Received event: {json.dumps(event)}")

    # Extract HTTP method and path
    # API Gateway HTTP API v2 format - path and httpMethod are at top level
    http_method = event.get("httpMethod") or event.get("requestContext", {}).get("http", {}).get(
        "method", "GET"
    )
    path = event.get("path") or event.get("requestContext", {}).get("http", {}).get("path", "/")

    # Route handling
    if path == "/health" and http_method == "GET":
        return _health_check()

    if path == "/analyze" and http_method == "POST":
        return _analyze_workflow(event)

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


def _analyze_workflow(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Analyze a GitHub Actions workflow run.

    Expected request body:
    {
        "owner": "username_or_org",
        "repo": "repository_name",
        "run_id": 123456789
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
        owner = body.get("owner")
        repo = body.get("repo")
        run_id = body.get("run_id")

        if not owner:
            return _error_response(400, "Missing required field: owner")
        if not repo:
            return _error_response(400, "Missing required field: repo")
        if not run_id:
            return _error_response(400, "Missing required field: run_id")

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

        # Analyze workflow
        try:
            analysis = analyzer.analyze(workflow_run, jobs)
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
