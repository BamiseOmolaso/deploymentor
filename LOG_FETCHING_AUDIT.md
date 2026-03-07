# Log Fetching Audit Report

**Date:** March 7, 2026  
**Purpose:** Audit current log fetching implementation in DeployMentor codebase

---

## Step 1: Files Reviewed

- ✅ `src/lambda_handler.py` (235 lines)
- ✅ `src/github/client.py` (155 lines)
- ✅ `src/analyzers/workflow_analyzer.py` (470 lines)
- ✅ `tests/test_github_client.py` (141 lines)
- ✅ `tests/test_analyzer.py` (306 lines)

---

## Step 2: Detailed Answers

### 1. Does `GitHubClient` have a method to fetch step-level logs?

**Answer:** Yes, but it's **workflow-level**, not step-level.

**Method:** `get_workflow_run_logs(owner: str, repo: str, run_id: int) -> bytes`

**Location:** `src/github/client.py` lines 139-154

**What it returns:**
- Raw log data as `bytes` (zip file from GitHub API)
- Endpoint: `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`
- Returns the entire workflow run logs as a zip archive

**Note:** This is workflow-level logs, not individual step logs. The zip contains logs for all jobs/steps in the run.

---

### 2. Is that method being called anywhere?

**Answer:** **NO** - `get_workflow_run_logs()` is **NOT called** in:
- ❌ `lambda_handler.py`
- ❌ `workflow_analyzer.py`

**Current calls in `lambda_handler.py` (lines 147-148):**
```python
workflow_run = github_client.get_workflow_run(owner, repo, run_id)
jobs = github_client.get_workflow_run_jobs(owner, repo, run_id)
```

Only workflow metadata and job metadata are fetched. **Logs are never fetched.**

---

### 3. Where does `error_message` get set? Why is it returning `null`?

**Answer:** It's **hardcoded to `None`** and never populated.

**Location:** `src/analyzers/workflow_analyzer.py` line 281

**Current implementation:**
```python
# Line 278-281
# Try to extract error message from step logs
# Note: GitHub API doesn't always provide logs in step data
# We'll need to fetch logs separately if needed
error_message = None
```

**Why it's null:**
- Hardcoded to `None` (line 281)
- Never populated from any source
- Comment indicates logs need to be fetched separately
- Returned as `null` in the response (line 302)

**The step analysis only uses:**
- Step name (for pattern matching)
- Step conclusion/status
- **No actual log content**

---

### 4. What data is currently being passed into `WorkflowAnalyzer.analyze()`?

**Answer:** **Only metadata, no log content.**

**In `lambda_handler.py` line 160:**
```python
analysis = analyzer.analyze(workflow_run, jobs)
```

**`workflow_run` (from `get_workflow_run()`):**
- Workflow ID, name, status, conclusion
- Timestamps, actor, head branch
- **No log content**

**`jobs` (from `get_workflow_run_jobs()`):**
- Job metadata: ID, name, conclusion, status
- Step metadata: name, conclusion, status, number
- **No log content or error messages**

**The analyzer relies on step names for pattern matching** (e.g., "Terraform Plan" → terraform error type).

---

### 5. Are there existing tests that cover log fetching?

**Answer:** Yes, but **minimal coverage**.

**Test:** `test_get_workflow_run_logs_success` in `tests/test_github_client.py` (lines 96-108)

**What it mocks:**
- Mocks `requests.Session.get` to return a response
- Sets `mock_response.content = b"log data here"`
- Verifies the method exists and returns bytes
- **Does NOT test:**
  - Log parsing/extraction
  - Zip file handling
  - Step-level log extraction
  - Integration with analyzer

**No tests cover:**
- Using logs in `WorkflowAnalyzer`
- Extracting error messages from logs
- Parsing the zip file structure

---

## Step 3: Findings Summary

### ✅ What is Already There and Working

1. **`GitHubClient.get_workflow_run_logs()` method exists**
   - Fetches workflow run logs as a zip file
   - Has basic error handling
   - Tested at unit level

2. **Workflow and job metadata fetching**
   - `get_workflow_run()` and `get_workflow_run_jobs()` are used
   - Data flows to `WorkflowAnalyzer`

3. **Error type detection from step names**
   - Pattern matching on step names works
   - Can identify error types (terraform, timeout, etc.) from names

---

### ⚠️ What Exists But Is NOT Connected

1. **`get_workflow_run_logs()` method**
   - ✅ Implemented and tested
   - ❌ **NOT called** in workflow analysis path
   - ❌ **NOT integrated** with `WorkflowAnalyzer`

2. **Log fetching capability**
   - Infrastructure exists to fetch logs
   - No parsing or extraction logic
   - No step-level log extraction

---

### ❌ What is Genuinely Missing (Needs to Be Written)

1. **Log Parsing/Extraction Logic**
   - Zip file extraction (GitHub returns logs as a zip)
   - Step-level log extraction from zip structure
   - Error message extraction from log content

2. **Integration with Analyzer**
   - Call `get_workflow_run_logs()` in `_analyze_workflow()`
   - Pass log content to `WorkflowAnalyzer.analyze()` (or new method)
   - Extract error messages from logs and populate `error_message`

3. **Log Content Analysis**
   - Parse log text for error patterns
   - Extract specific error messages from logs
   - Match logs to specific steps

4. **Enhanced Tests**
   - Test zip file parsing
   - Test step-level log extraction
   - Test error message extraction
   - Test integration with analyzer

5. **Error Handling**
   - Handle expired logs (GitHub logs expire after ~90 days)
   - Handle missing logs
   - Handle malformed zip files
   - Handle log parsing errors

---

## Summary

**Current State:**
- ✅ Log fetching method exists but is **unused**
- ✅ Analysis works but relies on **step names only**
- ❌ `error_message` is **always `null`**
- ❌ **No log content** is analyzed

**To Enable Log-Based Analysis:**
1. Call `get_workflow_run_logs()` in workflow analysis path
2. Parse zip file and extract step-level logs
3. Extract error messages from log content
4. Pass log content to analyzer (or enhance analyzer to use logs)
5. Populate `error_message` from actual log content

**The foundation exists; integration and parsing logic are missing.**

