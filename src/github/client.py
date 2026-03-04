"""
GitHub API client for fetching workflow run data.

This module handles authentication and API calls to GitHub.
"""

import logging
import os
from typing import Any, Dict, Optional

import requests

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
        
        Args:
            token: GitHub personal access token (if None, will fetch from SSM)
        """
        self.token = token or self._get_token_from_ssm()
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"token {self.token}",
            "Accept": "application/vnd.github.v3+json",
        })
    
    def _get_token_from_ssm(self) -> str:
        """
        Fetch GitHub token from SSM Parameter Store.
        
        Returns:
            GitHub personal access token
            
        Raises:
            ValueError: If token cannot be retrieved
        """
        # TODO: Implement SSM parameter retrieval
        # For now, raise error to ensure we don't hardcode secrets
        raise NotImplementedError(
            "SSM parameter retrieval not yet implemented. "
            "Token must be provided via environment variable for local dev."
        )
    
    def get_workflow_run(
        self, owner: str, repo: str, run_id: int
    ) -> Dict[str, Any]:
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
    
    def get_workflow_run_jobs(
        self, owner: str, repo: str, run_id: int
    ) -> Dict[str, Any]:
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
    
    def get_workflow_run_logs(
        self, owner: str, repo: str, run_id: int
    ) -> bytes:
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

