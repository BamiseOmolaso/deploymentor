"""
Log analyzer for DeployMentor.

Analyzes CI/CD logs to identify failures and root causes using pattern matching.
"""

import re
from typing import Dict


class LogAnalyzer:
    """
    Analyzes CI/CD logs to identify failures and root causes.
    """

    # Error patterns and their corresponding fixes
    ERROR_PATTERNS = {
        "iam_permissions": {
            "patterns": [
                r"AccessDenied",
                r"access denied",
                r"not authorized",
                r"unauthorized",
                r"permission denied",
                r"forbidden",
                r"403",
                r"401",
            ],
            "summary": "IAM permissions issue detected",
            "probable_cause": "The service account or IAM role lacks required permissions",
            "fix_steps": [
                "Check IAM policies attached to your role/service account",
                "Verify the specific permission needed (check error message)",
                "Add the missing permission to your IAM policy",
                "Wait a few minutes for IAM changes to propagate",
            ],
            "confidence": 0.9,
        },
        "file_not_found": {
            "patterns": [
                r"No such file or directory",
                r"file not found",
                r"cannot find.*file",
                r"path.*does not exist",
                r"ENOENT",
            ],
            "summary": "File or directory not found",
            "probable_cause": "Missing file or incorrect path in build context",
            "fix_steps": [
                "Verify the file path is correct",
                "Check if the file exists in your repository",
                "Ensure the file is included in your build context",
                "Verify working directory in your CI/CD configuration",
            ],
            "confidence": 0.85,
        },
        "python_module": {
            "patterns": [
                r"ModuleNotFoundError",
                r"No module named",
                r"ImportError",
                r"cannot import",
            ],
            "summary": "Python module/package not found",
            "probable_cause": "Missing Python dependency or incorrect environment",
            "fix_steps": [
                "Check if the module is listed in requirements.txt",
                "Verify your virtual environment is activated",
                "Run 'pip install -r requirements.txt'",
                "Check Python version compatibility",
            ],
            "confidence": 0.9,
        },
        "terraform_backend": {
            "patterns": [
                r"terraform init.*backend",
                r"backend.*error",
                r"backend.*not found",
                r"state.*locked",
                r"Error.*backend",
            ],
            "summary": "Terraform backend configuration issue",
            "probable_cause": "Backend configuration error or state lock",
            "fix_steps": [
                "Verify backend configuration in terraform block",
                "Check if S3 bucket/DynamoDB table exists",
                "If state is locked, check for other running Terraform processes",
                "Verify AWS credentials have access to backend resources",
            ],
            "confidence": 0.85,
        },
        "docker_build": {
            "patterns": [
                r"docker build.*failed",
                r"Dockerfile.*error",
                r"failed to build",
                r"docker.*error",
                r"build context",
            ],
            "summary": "Docker build failure",
            "probable_cause": "Dockerfile error or build context issue",
            "fix_steps": [
                "Check Dockerfile syntax and commands",
                "Verify all files referenced in Dockerfile exist",
                "Check build context includes required files",
                "Review Docker build logs for specific error",
            ],
            "confidence": 0.8,
        },
        "timeout": {
            "patterns": [
                r"timeout",
                r"timed out",
                r"exceeded.*time",
                r"execution time limit",
            ],
            "summary": "Operation timed out",
            "probable_cause": "Process exceeded time limit or network timeout",
            "fix_steps": [
                "Increase timeout value in your configuration",
                "Check network connectivity",
                "Optimize slow operations",
                "Consider breaking into smaller steps",
            ],
            "confidence": 0.75,
        },
        "network": {
            "patterns": [
                r"network error",
                r"connection.*refused",
                r"connection.*timeout",
                r"dns.*error",
                r"failed to fetch",
                r"could not resolve",
            ],
            "summary": "Network connectivity issue",
            "probable_cause": "Network error or DNS resolution failure",
            "fix_steps": [
                "Check network connectivity",
                "Verify DNS resolution",
                "Check firewall/security group rules",
                "Retry the operation",
            ],
            "confidence": 0.8,
        },
    }

    def analyze(self, logs: str, source: str = "github_actions") -> Dict[str, any]:
        """
        Analyze logs and return structured analysis.

        Args:
            logs: Log content as string
            source: Source of logs (e.g., "github_actions", "gitlab_ci")

        Returns:
            Dictionary with analysis results:
            {
                "summary": "...",
                "probable_cause": "...",
                "fix_steps": ["...", "..."],
                "confidence": 0.0-1.0
            }
        """
        if not logs or not logs.strip():
            return {
                "summary": "No logs provided",
                "probable_cause": "Logs are empty or missing",
                "fix_steps": ["Provide log content for analysis"],
                "confidence": 0.0,
            }

        logs_lower = logs.lower()

        # Find matching error patterns
        matches = []
        for error_type, error_info in self.ERROR_PATTERNS.items():
            for pattern in error_info["patterns"]:
                if re.search(pattern, logs_lower, re.IGNORECASE):
                    matches.append((error_type, error_info))
                    break  # Only match once per error type

        # If no matches found, return generic analysis
        if not matches:
            return {
                "summary": "No specific error pattern detected",
                "probable_cause": "Unknown error - review logs manually",
                "fix_steps": [
                    "Review the full error logs",
                    "Check CI/CD configuration",
                    "Verify environment variables and secrets",
                    "Check recent changes to your codebase",
                ],
                "confidence": 0.3,
            }

        # Use the first (highest priority) match
        error_type, error_info = matches[0]

        return {
            "summary": error_info["summary"],
            "probable_cause": error_info["probable_cause"],
            "fix_steps": error_info["fix_steps"],
            "confidence": error_info["confidence"],
        }
