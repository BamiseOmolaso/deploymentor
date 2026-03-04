"""
Utilities for AWS Systems Manager Parameter Store.

This module handles secure retrieval of secrets and configuration.
"""

import logging
from typing import Optional

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


def get_parameter(name: str, decrypt: bool = True) -> Optional[str]:
    """
    Retrieve a parameter from SSM Parameter Store.
    
    Args:
        name: Parameter name (e.g., '/deploymentor/github/token')
        decrypt: Whether to decrypt SecureString parameters
        
    Returns:
        Parameter value, or None if not found
        
    Raises:
        ClientError: If AWS API call fails
    """
    ssm_client = boto3.client("ssm")
    
    try:
        response = ssm_client.get_parameter(
            Name=name,
            WithDecryption=decrypt
        )
        return response["Parameter"]["Value"]
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code", "")
        if error_code == "ParameterNotFound":
            logger.warning(f"Parameter {name} not found in SSM")
            return None
        logger.error(f"Error retrieving parameter {name}: {e}")
        raise

