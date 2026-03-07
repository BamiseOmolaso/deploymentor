"""
GitHub API client for fetching workflow run data.

This module handles authentication and API calls to GitHub.
"""

import io
import logging
import os
import zipfile
from typing import Any, Dict, Optional

import requests

from src.utils.ssm import get_parameter

logger = logging.getLogger(__name__)


class GitHubClient:
    """
    Client for interacting with GitHub API.

    Uses GitHub token from SSM Parameter Store for authentication.
    """

    BASE_URL = "https://api.github.com"

    def __init__(self, token: Optional[str] = None):
        """
        Initialize GitHub client.

        Token resolution order:
        1. Explicit token parameter (if provided)
        2. GITHUB_TOKEN environment variable (for local development)
        3. SSM Parameter Store (for Lambda/production)

        Args:
            token: GitHub personal access token (if None, will check env var then SSM)
        """
        self.token = token or self._get_token()
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"token {self.token}",
                "Accept": "application/vnd.github.v3+json",
            }
        )

    def _get_token(self) -> str:
        """
        Get GitHub token from environment variable or SSM Parameter Store.

        Priority order:
        1. GITHUB_TOKEN environment variable (for local development)
        2. SSM Parameter Store (for Lambda/production)

        Returns:
            GitHub personal access token

        Raises:
            ValueError: If token cannot be retrieved from any source
        """
        # First, check for GITHUB_TOKEN environment variable (local development)
        env_token = os.getenv("GITHUB_TOKEN")
        if env_token:
            logger.info("Using GitHub token from GITHUB_TOKEN environment variable")
            return env_token

        # Fall back to SSM Parameter Store (Lambda/production)
        logger.info("GITHUB_TOKEN not found, attempting to retrieve from SSM Parameter Store")
        return self._get_token_from_ssm()

    def _get_token_from_ssm(self) -> str:
        """
        Fetch GitHub token from SSM Parameter Store.

        Returns:
            GitHub personal access token

        Raises:
            ValueError: If token cannot be retrieved or parameter path not configured
        """
        # Get SSM parameter path from environment variable
        param_path = os.getenv("GITHUB_TOKEN_SSM_PARAM")

        if not param_path:
            raise ValueError(
                "GitHub token not found. Neither GITHUB_TOKEN environment variable "
                "nor GITHUB_TOKEN_SSM_PARAM is set. "
                "For local development, set GITHUB_TOKEN. "
                "For Lambda, set GITHUB_TOKEN_SSM_PARAM environment variable."
            )

        # Retrieve token from SSM Parameter Store
        token = get_parameter(param_path, decrypt=True)

        if not token:
            raise ValueError(
                f"GitHub token not found in SSM Parameter Store at path: {param_path}. "
                "Please ensure the parameter exists and Lambda has read permissions."
            )

        logger.info(f"Successfully retrieved GitHub token from SSM: {param_path}")
        return token

    def get_workflow_run(self, owner: str, repo: str, run_id: int) -> Dict[str, Any]:
        """
        Fetch a specific workflow run.

        Args:
            owner: Repository owner (username or org)
            repo: Repository name
            run_id: Workflow run ID

        Returns:
            Workflow run data from GitHub API
        """
        url = f"{self.BASE_URL}/repos/{owner}/{repo}/actions/runs/{run_id}"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()

    def get_workflow_run_jobs(self, owner: str, repo: str, run_id: int) -> Dict[str, Any]:
        """
        Fetch jobs for a specific workflow run.

        Args:
            owner: Repository owner
            repo: Repository name
            run_id: Workflow run ID

        Returns:
            Jobs data from GitHub API
        """
        url = f"{self.BASE_URL}/repos/{owner}/{repo}/actions/runs/{run_id}/jobs"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()

    def get_workflow_run_logs(self, owner: str, repo: str, run_id: int) -> bytes:
        """
        Fetch logs for a workflow run.

        Args:
            owner: Repository owner
            repo: Repository name
            run_id: Workflow run ID

        Returns:
            Raw log data (zip file)
        """
        url = f"{self.BASE_URL}/repos/{owner}/{repo}/actions/runs/{run_id}/logs"
        response = self.session.get(url)
        response.raise_for_status()
        return response.content

    def parse_logs_zip(self, log_bytes: bytes) -> Dict[str, str]:
        """
        Parse GitHub Actions logs zip file into a dictionary.

        Args:
            log_bytes: Raw zip file bytes from get_workflow_run_logs()

        Returns:
            Dictionary mapping filename to log text content.
            Returns empty dict on any error (malformed zip, empty bytes).
            Never raises exceptions.
        """
        if not log_bytes:
            return {}

        try:
            log_dict = {}
            with zipfile.ZipFile(io.BytesIO(log_bytes), "r") as zip_file:
                for file_info in zip_file.namelist():
                    try:
                        # Read file content as text (GitHub logs are text files)
                        content = zip_file.read(file_info).decode("utf-8", errors="replace")
                        log_dict[file_info] = content
                    except Exception as e:
                        logger.warning(f"Failed to read file {file_info} from logs zip: {e}")
                        continue
            return log_dict
        except zipfile.BadZipFile:
            logger.warning("Invalid zip file format in logs")
            return {}
        except Exception as e:
            logger.warning(f"Error parsing logs zip: {e}")
            return {}
