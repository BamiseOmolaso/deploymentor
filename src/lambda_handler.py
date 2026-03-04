"""
Main Lambda handler for DeployMentor API.

This is the entry point for all API Gateway requests.
"""

import json
import logging
from typing import Any, Dict

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
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("requestContext", {}).get("http", {}).get("path", "/")
    
    # Route handling (to be implemented)
    if path == "/health" and http_method == "GET":
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
            },
            "body": json.dumps({
                "status": "healthy",
                "service": "deploymentor",
                "version": "0.1.0"
            })
        }
    
    # Default 404 response
    return {
        "statusCode": 404,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({
            "error": "Not Found",
            "message": f"No handler for {http_method} {path}"
        })
    }

