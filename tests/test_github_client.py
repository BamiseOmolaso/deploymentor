"""
Tests for GitHub client.
"""

import os
from unittest.mock import MagicMock, patch

import pytest
import requests

from src.github.client import GitHubClient


class TestGitHubClientTokenRetrieval:
    """Test token retrieval logic."""

    def test_token_from_explicit_parameter(self):
        """Test that explicit token parameter is used."""
        client = GitHubClient(token="explicit_token")
        assert client.token == "explicit_token"

    @patch.dict(os.environ, {"GITHUB_TOKEN": "env_token"})
    def test_token_from_environment_variable(self):
        """Test that GITHUB_TOKEN env var is used when no explicit token."""
        # Remove SSM param to force env var usage
        with patch.dict(os.environ, {}, clear=False):
            os.environ["GITHUB_TOKEN"] = "env_token"
            os.environ.pop("GITHUB_TOKEN_SSM_PARAM", None)
            client = GitHubClient()
            assert client.token == "env_token"

    @patch("src.github.client.get_parameter")
    def test_token_from_ssm_parameter_store(self, mock_get_parameter):
        """Test that SSM Parameter Store is used when env var not set."""
        mock_get_parameter.return_value = "ssm_token"
        with patch.dict(os.environ, {"GITHUB_TOKEN_SSM_PARAM": "/test/path"}, clear=False):
            os.environ.pop("GITHUB_TOKEN", None)
            client = GitHubClient()
            assert client.token == "ssm_token"
            mock_get_parameter.assert_called_once_with("/test/path", decrypt=True)

    @patch("src.github.client.get_parameter")
    def test_token_ssm_parameter_not_found(self, mock_get_parameter):
        """Test error when SSM parameter not found."""
        mock_get_parameter.return_value = None
        with patch.dict(os.environ, {"GITHUB_TOKEN_SSM_PARAM": "/test/path"}, clear=False):
            os.environ.pop("GITHUB_TOKEN", None)
            with pytest.raises(ValueError, match="GitHub token not found in SSM"):
                GitHubClient()

    def test_token_no_source_available(self):
        """Test error when no token source is available."""
        with patch.dict(os.environ, {}, clear=True):
            with pytest.raises(ValueError, match="Neither GITHUB_TOKEN"):
                GitHubClient()


class TestGitHubClientAPI:
    """Test GitHub API calls."""

    @pytest.fixture
    def github_client(self):
        """Create GitHub client with mock token."""
        return GitHubClient(token="test_token")

    @patch("requests.Session.get")
    def test_get_workflow_run_success(self, mock_get, github_client):
        """Test successful workflow run retrieval."""
        mock_response = MagicMock()
        mock_response.json.return_value = {"id": 12345, "name": "CI", "conclusion": "failure"}
        mock_response.raise_for_status = MagicMock()
        mock_get.return_value = mock_response

        result = github_client.get_workflow_run("owner", "repo", 12345)

        assert result["id"] == 12345
        assert result["name"] == "CI"
        mock_get.assert_called_once()
        assert "repos/owner/repo/actions/runs/12345" in mock_get.call_args[0][0]

    @patch("requests.Session.get")
    def test_get_workflow_run_jobs_success(self, mock_get, github_client):
        """Test successful workflow run jobs retrieval."""
        mock_response = MagicMock()
        mock_response.json.return_value = {"jobs": [{"id": 1, "name": "test"}]}
        mock_response.raise_for_status = MagicMock()
        mock_get.return_value = mock_response

        result = github_client.get_workflow_run_jobs("owner", "repo", 12345)

        assert "jobs" in result
        assert len(result["jobs"]) == 1
        mock_get.assert_called_once()
        assert "repos/owner/repo/actions/runs/12345/jobs" in mock_get.call_args[0][0]

    @patch("requests.Session.get")
    def test_get_workflow_run_logs_success(self, mock_get, github_client):
        """Test successful workflow run logs retrieval."""
        mock_response = MagicMock()
        mock_response.content = b"log data here"
        mock_response.raise_for_status = MagicMock()
        mock_get.return_value = mock_response

        result = github_client.get_workflow_run_logs("owner", "repo", 12345)

        assert result == b"log data here"
        mock_get.assert_called_once()
        assert "repos/owner/repo/actions/runs/12345/logs" in mock_get.call_args[0][0]

    @patch("requests.Session.get")
    def test_get_workflow_run_not_found(self, mock_get, github_client):
        """Test error handling for 404 Not Found."""
        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = requests.HTTPError("404 Not Found")
        mock_get.return_value = mock_response

        with pytest.raises(requests.HTTPError):
            github_client.get_workflow_run("owner", "repo", 99999)

    @patch("requests.Session.get")
    def test_get_workflow_run_api_error(self, mock_get, github_client):
        """Test error handling for API errors."""
        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = requests.HTTPError("500 Internal Server Error")
        mock_get.return_value = mock_response

        with pytest.raises(requests.HTTPError):
            github_client.get_workflow_run("owner", "repo", 12345)

    def test_authorization_header_set(self):
        """Test that Authorization header is set correctly."""
        client = GitHubClient(token="test_token_123")
        assert "Authorization" in client.session.headers
        assert client.session.headers["Authorization"] == "token test_token_123"

    def test_accept_header_set(self):
        """Test that Accept header is set correctly."""
        client = GitHubClient(token="test_token")
        assert "Accept" in client.session.headers
        assert client.session.headers["Accept"] == "application/vnd.github.v3+json"
