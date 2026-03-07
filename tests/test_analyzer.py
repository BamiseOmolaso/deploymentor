"""
Tests for workflow analyzer.
"""

import pytest

from src.analyzers import WorkflowAnalyzer


class TestWorkflowAnalyzer:
    """Test WorkflowAnalyzer class."""

    @pytest.fixture
    def analyzer(self):
        """Create analyzer instance."""
        return WorkflowAnalyzer()

    @pytest.fixture
    def sample_failed_workflow(self):
        """Sample failed workflow run data."""
        return {
            "id": 12345,
            "name": "CI",
            "conclusion": "failure",
            "status": "completed",
        }

    @pytest.fixture
    def sample_successful_workflow(self):
        """Sample successful workflow run data."""
        return {
            "id": 12346,
            "name": "CI",
            "conclusion": "success",
            "status": "completed",
        }

    @pytest.fixture
    def sample_failed_jobs(self):
        """Sample failed jobs data."""
        return {
            "jobs": [
                {
                    "id": 67890,
                    "name": "test",
                    "conclusion": "failure",
                    "status": "completed",
                    "started_at": "2024-01-01T00:00:00Z",
                    "completed_at": "2024-01-01T00:05:00Z",
                    "steps": [
                        {
                            "id": 1,
                            "name": "Setup",
                            "conclusion": "success",
                            "status": "completed",
                        },
                        {
                            "id": 2,
                            "name": "Run tests - timeout error",
                            "conclusion": "failure",
                            "status": "completed",
                        },
                    ],
                }
            ]
        }

    def test_analyze_successful_workflow(self, analyzer, sample_successful_workflow):
        """Test analysis of successful workflow."""
        jobs = {"jobs": []}
        result = analyzer.analyze(sample_successful_workflow, jobs)

        assert result["workflow_id"] == 12346
        assert result["analysis"]["failed"] is False
        assert "did not fail" in result["analysis"]["message"]

    def test_analyze_failed_workflow(self, analyzer, sample_failed_workflow, sample_failed_jobs):
        """Test analysis of failed workflow."""
        result = analyzer.analyze(sample_failed_workflow, sample_failed_jobs)

        assert result["workflow_id"] == 12345
        assert result["analysis"]["failed"] is True
        assert result["failed_jobs_count"] == 1
        assert "root_cause" in result["analysis"]
        assert "job_analyses" in result["analysis"]

    def test_analyze_cancelled_workflow(self, analyzer):
        """Test analysis of cancelled workflow."""
        workflow = {
            "id": 12347,
            "name": "CI",
            "conclusion": "cancelled",
            "status": "completed",
        }
        jobs = {"jobs": []}
        result = analyzer.analyze(workflow, jobs)

        # Cancelled workflows are treated as not failed (different from failure)
        assert result["analysis"]["failed"] is False
        assert result["conclusion"] == "cancelled"

    def test_analyze_workflow_no_failed_jobs(self, analyzer, sample_failed_workflow):
        """Test analysis when workflow failed but no failed jobs found."""
        jobs = {"jobs": []}
        result = analyzer.analyze(sample_failed_workflow, jobs)

        assert result["analysis"]["failed"] is True
        assert "no failed jobs found" in result["analysis"]["message"]

    def test_identify_error_type_timeout(self, analyzer):
        """Test timeout error identification."""
        error_type = analyzer._identify_error_type("Workflow timed out after 30 minutes")
        assert error_type == "timeout"

    def test_identify_error_type_dependency(self, analyzer):
        """Test dependency error identification."""
        error_type = analyzer._identify_error_type("npm error: package not found")
        assert error_type == "dependency"

    def test_identify_error_type_syntax(self, analyzer):
        """Test syntax error identification."""
        error_type = analyzer._identify_error_type("Syntax error: unexpected token")
        assert error_type == "syntax"

    def test_identify_error_type_permission(self, analyzer):
        """Test permission error identification."""
        error_type = analyzer._identify_error_type("403 Forbidden: permission denied")
        assert error_type == "permission"

    def test_identify_error_type_network(self, analyzer):
        """Test network error identification."""
        error_type = analyzer._identify_error_type("Network error: connection refused")
        assert error_type == "network"

    def test_identify_error_type_resource(self, analyzer):
        """Test resource error identification."""
        error_type = analyzer._identify_error_type("Out of memory error")
        assert error_type == "resource"

    def test_identify_error_type_configuration(self, analyzer):
        """Test configuration error identification."""
        error_type = analyzer._identify_error_type("Invalid config: missing required env")
        assert error_type == "configuration"

    def test_identify_error_type_none(self, analyzer):
        """Test that unknown errors return None."""
        error_type = analyzer._identify_error_type("Some random error message")
        assert error_type is None

    def test_get_failed_jobs(self, analyzer, sample_failed_jobs):
        """Test extraction of failed jobs."""
        failed_jobs = analyzer._get_failed_jobs(sample_failed_jobs)
        assert len(failed_jobs) == 1
        assert failed_jobs[0]["id"] == 67890

    def test_get_failed_jobs_empty(self, analyzer):
        """Test extraction when no failed jobs."""
        jobs = {"jobs": []}
        failed_jobs = analyzer._get_failed_jobs(jobs)
        assert len(failed_jobs) == 0

    def test_get_failed_jobs_mixed(self, analyzer):
        """Test extraction with mixed success/failure jobs."""
        jobs = {
            "jobs": [
                {"id": 1, "conclusion": "success"},
                {"id": 2, "conclusion": "failure"},
                {"id": 3, "conclusion": "success"},
                {"id": 4, "conclusion": "failure"},
            ]
        }
        failed_jobs = analyzer._get_failed_jobs(jobs)
        assert len(failed_jobs) == 2
        assert failed_jobs[0]["id"] == 2
        assert failed_jobs[1]["id"] == 4

    def test_analyze_job(self, analyzer):
        """Test job analysis."""
        job = {
            "id": 67890,
            "name": "test",
            "conclusion": "failure",
            "started_at": "2024-01-01T00:00:00Z",
            "completed_at": "2024-01-01T00:05:00Z",
            "steps": [
                {"name": "Setup", "conclusion": "success"},
                {"name": "Run tests - timeout", "conclusion": "failure"},
            ],
        }
        result = analyzer._analyze_job(job)

        assert result["job_id"] == 67890
        assert result["job_name"] == "test"
        assert result["failed_steps_count"] == 1
        assert len(result["step_analyses"]) == 1

    def test_analyze_job_no_failed_steps(self, analyzer):
        """Test job analysis with no failed steps."""
        job = {
            "id": 67890,
            "name": "test",
            "conclusion": "failure",
            "steps": [],
        }
        result = analyzer._analyze_job(job)

        assert result["failed_steps_count"] == 0
        # When job fails with no steps, we add a placeholder step analysis
        # So expect 1 step analysis instead of 0
        assert len(result["step_analyses"]) == 1
        assert result["step_analyses"][0]["step_name"] == "Job failed before steps executed"

    def test_determine_primary_error_type_priority(self, analyzer):
        """Test error type priority ordering."""
        error_types = {"syntax", "dependency", "timeout"}
        step_analyses = []
        primary = analyzer._determine_primary_error_type(error_types, step_analyses)

        # Configuration has highest priority, but not in set
        # Dependency should be selected over syntax
        assert primary == "dependency"

    def test_determine_primary_error_type_configuration(self, analyzer):
        """Test configuration error has highest priority."""
        error_types = {"configuration", "syntax", "timeout"}
        step_analyses = []
        primary = analyzer._determine_primary_error_type(error_types, step_analyses)

        assert primary == "configuration"

    def test_determine_primary_error_type_empty(self, analyzer):
        """Test primary error type with empty set."""
        error_types = set()
        step_analyses = []
        primary = analyzer._determine_primary_error_type(error_types, step_analyses)

        assert primary is None

    def test_aggregate_error_types(self, analyzer):
        """Test error type aggregation."""
        job_analyses = [
            {
                "error_type": "dependency",
                "step_analyses": [{"error_type": "syntax"}],
            },
            {
                "error_type": "timeout",
                "step_analyses": [],
            },
        ]
        error_types = analyzer._aggregate_error_types(job_analyses)

        assert len(error_types) == 3
        assert "dependency" in error_types
        assert "syntax" in error_types
        assert "timeout" in error_types

    def test_generate_suggestions_timeout(self, analyzer):
        """Test suggestion generation for timeout errors."""
        error_types = ["timeout"]
        suggestions = analyzer._generate_suggestions(error_types, None)

        assert len(suggestions) > 0
        assert any("timeout" in s.lower() for s in suggestions)

    def test_generate_suggestions_dependency(self, analyzer):
        """Test suggestion generation for dependency errors."""
        error_types = ["dependency"]
        suggestions = analyzer._generate_suggestions(error_types, None)

        assert len(suggestions) > 0
        assert any("dependency" in s.lower() or "package" in s.lower() for s in suggestions)

    def test_generate_suggestions_multiple(self, analyzer):
        """Test suggestion generation for multiple error types."""
        error_types = ["timeout", "dependency", "syntax"]
        suggestions = analyzer._generate_suggestions(error_types, None)

        assert len(suggestions) > 1

    def test_generate_suggestions_no_error_types(self, analyzer):
        """Test suggestion generation when no error types."""
        error_types = []
        root_cause = {"job_name": "test-job"}
        suggestions = analyzer._generate_suggestions(error_types, root_cause)

        assert len(suggestions) > 0
        assert any("test-job" in s for s in suggestions)

    def test_analyze_empty_workflow_data(self, analyzer):
        """Test analysis with empty workflow data."""
        workflow = {}
        jobs = {}
        result = analyzer.analyze(workflow, jobs)

        # Should handle gracefully
        assert "analysis" in result

    def test_analyze_malformed_jobs_data(self, analyzer, sample_failed_workflow):
        """Test analysis with malformed jobs data."""
        jobs = {"jobs": None}
        result = analyzer.analyze(sample_failed_workflow, jobs)

        # Should handle gracefully
        assert "analysis" in result

    def test_analyze_step_extracts_error_from_job_log(self, analyzer):
        """Test that _analyze_step extracts error message from job-level log content."""
        step = {
            "name": "Terraform Plan",
            "conclusion": "failure",
            "status": "completed",
            "number": 10,
        }

        # Simulate GitHub log structure: job-level log with step markers
        parsed_logs = {
            "0_Deploy to AWS.txt": """2024-01-01T00:00:00Z Starting job
##[group]Run Terraform Plan
2024-01-01T00:01:00Z Running terraform plan...
Error: Invalid resource configuration
  on main.tf line 42, in resource "aws_lambda_function" "this":
  42:   runtime = "python3.12"
Invalid runtime version.
##[endgroup]
2024-01-01T00:02:00Z Job completed""",
        }

        result = analyzer._analyze_step(step, parsed_logs)

        assert result["error_type"] == "terraform"
        assert result["error_message"] is not None
        assert "Error" in result["error_message"] or "error" in result["error_message"].lower()
