"""
Workflow analyzer for DeployMentor.

Analyzes failed GitHub Actions workflow runs and identifies root causes.
"""

import logging
import re
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class WorkflowAnalyzer:
    """
    Analyzes GitHub Actions workflow runs to identify failures and root causes.
    """

    # Common error patterns
    ERROR_PATTERNS = {
        "timeout": [
            r"timeout",
            r"timed out",
            r"exceeded.*time",
            r"execution time limit",
        ],
        "dependency": [
            r"module not found",
            r"package.*not found",
            r"cannot find module",
            r"dependency.*failed",
            r"npm.*error",
            r"pip.*error",
            r"failed to install",
        ],
        "syntax": [
            r"syntax error",
            r"parse error",
            r"invalid syntax",
            r"unexpected token",
            r"unexpected end",
        ],
        "permission": [
            r"permission denied",
            r"access denied",
            r"unauthorized",
            r"forbidden",
            r"403",
            r"401",
        ],
        "network": [
            r"network error",
            r"connection.*refused",
            r"connection.*timeout",
            r"dns.*error",
            r"failed to fetch",
            r"could not resolve",
        ],
        "resource": [
            r"out of memory",
            r"disk.*full",
            r"no space left",
            r"quota.*exceeded",
            r"resource.*unavailable",
        ],
        "configuration": [
            r"invalid.*config",
            r"missing.*required",
            r"configuration.*error",
            r"env.*not set",
            r"environment.*variable",
            r"validate.*failed",  # Terraform/validation failures
            r"validation.*error",
            r"terraform.*validate",
            r"terraform.*error",
            r"terraform.*failed",
        ],
        "terraform": [
            r"terraform.*error",
            r"terraform.*failed",
            r"terraform.*validate",
            r"terraform.*plan",
            r"terraform.*apply",
            r"terraform exited",
            r"exit code [13]",
        ],
    }

    def analyze(self, workflow_run: Dict[str, Any], jobs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Analyze a failed workflow run.

        Args:
            workflow_run: Workflow run data from GitHub API
            jobs: Jobs data from GitHub API

        Returns:
            Analysis result with root cause and suggestions
        """
        logger.info(f"Analyzing workflow run {workflow_run.get('id')}")

        # Extract basic information
        run_id = workflow_run.get("id")
        workflow_name = workflow_run.get("name", "Unknown")
        conclusion = workflow_run.get("conclusion")
        status = workflow_run.get("status")

        # Check if workflow actually failed (cancelled workflows are not failures)
        if conclusion != "failure":
            return {
                "workflow_id": run_id,
                "workflow_name": workflow_name,
                "status": status,
                "conclusion": conclusion,
                "analysis": {
                    "failed": False,
                    "message": f"Workflow did not fail (conclusion: {conclusion})",
                },
            }

        # Analyze failed jobs
        failed_jobs = self._get_failed_jobs(jobs)
        if not failed_jobs:
            return {
                "workflow_id": run_id,
                "workflow_name": workflow_name,
                "status": status,
                "conclusion": conclusion,
                "analysis": {
                    "failed": True,
                    "message": "Workflow failed but no failed jobs found",
                },
            }

        # Analyze each failed job
        job_analyses = []
        for job in failed_jobs:
            job_analysis = self._analyze_job(job)
            job_analyses.append(job_analysis)

        # Determine root cause (first failed job is usually the root cause)
        root_cause = job_analyses[0] if job_analyses else None

        # Aggregate error types
        error_types = self._aggregate_error_types(job_analyses)

        return {
            "workflow_id": run_id,
            "workflow_name": workflow_name,
            "status": status,
            "conclusion": conclusion,
            "failed_jobs_count": len(failed_jobs),
            "analysis": {
                "failed": True,
                "root_cause": root_cause,
                "error_types": error_types,
                "job_analyses": job_analyses,
                "suggestions": self._generate_suggestions(error_types, root_cause),
            },
        }

    def _get_failed_jobs(self, jobs: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Extract failed jobs from jobs data.

        Args:
            jobs: Jobs data from GitHub API

        Returns:
            List of failed job dictionaries
        """
        failed_jobs = []
        jobs_list = jobs.get("jobs", [])

        # Handle None or invalid jobs list
        if jobs_list is None:
            return failed_jobs

        for job in jobs_list:
            conclusion = job.get("conclusion")
            if conclusion == "failure":
                failed_jobs.append(job)

        return failed_jobs

    def _analyze_job(self, job: Dict[str, Any]) -> Dict[str, Any]:
        """
        Analyze a single failed job.

        Args:
            job: Job data from GitHub API

        Returns:
            Analysis of the job
        """
        job_id = job.get("id")
        job_name = job.get("name", "Unknown")
        conclusion = job.get("conclusion")
        status = job.get("status")
        started_at = job.get("started_at")
        completed_at = job.get("completed_at")

        # Extract steps
        steps = job.get("steps", [])
        failed_steps = [step for step in steps if step.get("conclusion") == "failure"]

        # Analyze failed steps
        step_analyses = []
        error_types = set()

        for step in failed_steps:
            step_analysis = self._analyze_step(step)
            step_analyses.append(step_analysis)
            if step_analysis.get("error_type"):
                error_types.add(step_analysis["error_type"])

        # If no steps failed but job failed, analyze job-level indicators
        if not failed_steps and conclusion == "failure":
            # Try to identify error from job name
            job_error_type = self._identify_error_type(job_name)
            if job_error_type:
                error_types.add(job_error_type)

            # Check if job has no steps (might indicate early failure)
            if not steps:
                logger.warning(
                    f"Job '{job_name}' failed with no steps - "
                    f"may indicate early failure or API limitation"
                )
                # Add a placeholder step analysis to indicate the issue
                step_analyses.append(
                    {
                        "step_name": "Job failed before steps executed",
                        "conclusion": "failure",
                        "error_type": job_error_type or "unknown",
                        "error_message": (
                            "No step details available. " "Check workflow logs or job status."
                        ),
                    }
                )

        # Determine primary error type
        primary_error_type = self._determine_primary_error_type(error_types, step_analyses)

        # If still no error type, try to infer from job name
        if not primary_error_type and conclusion == "failure":
            primary_error_type = self._identify_error_type(job_name)

        return {
            "job_id": job_id,
            "job_name": job_name,
            "conclusion": conclusion,
            "status": status,
            "started_at": started_at,
            "completed_at": completed_at,
            "failed_steps_count": len(failed_steps),
            "total_steps_count": len(steps),
            "error_type": primary_error_type,
            "step_analyses": step_analyses,
            "has_step_details": len(steps) > 0,
        }

    def _analyze_step(self, step: Dict[str, Any]) -> Dict[str, Any]:
        """
        Analyze a single failed step.

        Args:
            step: Step data from GitHub API

        Returns:
            Analysis of the step
        """
        step_name = step.get("name", "Unknown")
        conclusion = step.get("conclusion")
        status = step.get("status")
        number = step.get("number")

        # Try to extract error message from step logs
        # Note: GitHub API doesn't always provide logs in step data
        # We'll need to fetch logs separately if needed
        error_message = None

        # Check for common error patterns in step name
        # Also check status field as it might indicate failure
        is_failed = (
            conclusion == "failure"
            or status == "failure"
            or "error" in step_name.lower()
            or "failed" in step_name.lower()
        )

        # Check for common error patterns in step name or logs
        error_type = self._identify_error_type(step_name, error_message)

        return {
            "step_name": step_name,
            "conclusion": conclusion,
            "status": status,
            "number": number,
            "is_failed": is_failed,
            "error_type": error_type,
            "error_message": error_message,
        }

    def _identify_error_type(self, text: str, error_message: Optional[str] = None) -> Optional[str]:
        """
        Identify error type from text.

        Args:
            text: Text to analyze (step name, log output, etc.)
            error_message: Optional error message

        Returns:
            Error type identifier or None
        """
        combined_text = f"{text} {error_message or ''}".lower()

        # Check for Terraform-specific patterns first (more specific)
        if "terraform" in combined_text:
            for pattern in self.ERROR_PATTERNS.get("terraform", []):
                if re.search(pattern, combined_text, re.IGNORECASE):
                    return "terraform"
            # If Terraform-related but no specific pattern, still return terraform
            if any(keyword in combined_text for keyword in ["validate", "plan", "apply", "init"]):
                return "terraform"

        # Check for validation failures (common in CI/CD)
        if "validate" in combined_text and ("failed" in combined_text or "error" in combined_text):
            return "configuration"

        # Check all other patterns
        for error_type, patterns in self.ERROR_PATTERNS.items():
            if error_type == "terraform":  # Skip, already checked
                continue
            for pattern in patterns:
                if re.search(pattern, combined_text, re.IGNORECASE):
                    return error_type

        return None

    def _determine_primary_error_type(
        self, error_types: set, step_analyses: List[Dict[str, Any]]
    ) -> Optional[str]:
        """
        Determine the primary error type from multiple error types.

        Args:
            error_types: Set of error type strings
            step_analyses: List of step analyses

        Returns:
            Primary error type or None
        """
        if not error_types:
            return None

        # Priority order: terraform > configuration > dependency > syntax > others
        priority_order = [
            "terraform",
            "configuration",
            "dependency",
            "syntax",
            "permission",
            "timeout",
        ]

        for error_type in priority_order:
            if error_type in error_types:
                return error_type

        # Return first error type if no priority match
        return list(error_types)[0]

    def _aggregate_error_types(self, job_analyses: List[Dict[str, Any]]) -> List[str]:
        """
        Aggregate all error types from job analyses.

        Args:
            job_analyses: List of job analyses

        Returns:
            List of unique error types
        """
        error_types = set()

        for job_analysis in job_analyses:
            if job_analysis.get("error_type"):
                error_types.add(job_analysis["error_type"])

            # Also check step analyses
            for step_analysis in job_analysis.get("step_analyses", []):
                if step_analysis.get("error_type"):
                    error_types.add(step_analysis["error_type"])

        return sorted(list(error_types))

    def _generate_suggestions(
        self, error_types: List[str], root_cause: Optional[Dict[str, Any]]
    ) -> List[str]:
        """
        Generate suggestions based on error types.

        Args:
            error_types: List of error type identifiers
            root_cause: Root cause analysis

        Returns:
            List of suggestion strings
        """
        suggestions = []

        if "timeout" in error_types:
            suggestions.append(
                "Workflow timed out. Consider increasing timeout limits or optimizing slow steps."
            )

        if "dependency" in error_types:
            suggestions.append(
                "Dependency installation failed. "
                "Check package.json, requirements.txt, or other dependency files."
            )
            suggestions.append("Verify all dependencies are available and versions are correct.")

        if "syntax" in error_types:
            suggestions.append("Syntax error detected. Review the code in the failing step.")
            suggestions.append("Check for typos, missing brackets, or incorrect syntax.")

        if "permission" in error_types:
            suggestions.append(
                "Permission error detected. Check GitHub token permissions and repository access."
            )
            suggestions.append("Verify secrets and environment variables are correctly configured.")

        if "network" in error_types:
            suggestions.append(
                "Network error detected. "
                "Check internet connectivity and external service availability."
            )

        if "resource" in error_types:
            suggestions.append(
                "Resource limit exceeded. Consider optimizing resource usage or upgrading runner."
            )

        if "configuration" in error_types:
            suggestions.append(
                "Configuration error detected. "
                "Check workflow YAML syntax and required environment variables."
            )

        if "terraform" in error_types:
            suggestions.append(
                "Terraform validation or execution failed. "
                "Check Terraform configuration files for syntax errors or missing resources."
            )
            suggestions.append(
                "Review Terraform plan output for detailed error messages. "
                "Common issues include: invalid resource configurations, "
                "missing variables, or state conflicts."
            )

        if not suggestions:
            suggestions.append("Review the failed job logs for more details.")
            if root_cause:
                suggestions.append(
                    f"Focus on the first failed job: {root_cause.get('job_name', 'Unknown')}"
                )

        return suggestions
