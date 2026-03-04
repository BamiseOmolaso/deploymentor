# Enhancing Error Detection in Workflow Analysis

## Current State

The analyzer currently:
- ✅ Fetches workflow run and jobs data
- ✅ Identifies failed jobs
- ✅ Attempts to analyze steps
- ⚠️ **Limitation**: Step-level error details are often empty

## Why Step Details Are Empty

1. **GitHub API Limitation**: The `/jobs` endpoint doesn't always include detailed step error messages
2. **Log Expiration**: Workflow logs expire after ~90 days (410 Gone error)
3. **Step Data Structure**: Steps may not have `conclusion: "failure"` even when the job fails

## Solutions to Get More Error Details

### Option 1: Parse Step Names and Status (Immediate)

**What**: Extract error information from step names and status fields

**Implementation**:
```python
def _analyze_step(self, step: Dict[str, Any]) -> Dict[str, Any]:
    step_name = step.get("name", "Unknown")
    conclusion = step.get("conclusion")
    status = step.get("status")
    
    # Check for failure indicators
    is_failed = (
        conclusion == "failure" or
        status == "failure" or
        "error" in step_name.lower() or
        "failed" in step_name.lower()
    )
    
    # Extract error type from step name
    error_type = self._identify_error_type(step_name)
    
    return {
        "step_name": step_name,
        "conclusion": conclusion,
        "status": status,
        "is_failed": is_failed,
        "error_type": error_type,
    }
```

**Pros**: 
- Works immediately
- No additional API calls
- Fast

**Cons**:
- Limited error details
- Relies on step naming conventions

### Option 2: Fetch and Parse Logs (When Available)

**What**: Download workflow logs (zip file) and parse error messages

**Implementation**:
```python
def analyze_with_logs(self, workflow_run, jobs, logs_zip: bytes):
    # Extract logs from zip
    import zipfile
    import io
    
    log_content = {}
    with zipfile.ZipFile(io.BytesIO(logs_zip)) as zip_file:
        for name in zip_file.namelist():
            if name.endswith('.txt'):
                log_content[name] = zip_file.read(name).decode('utf-8', errors='ignore')
    
    # Parse logs for error patterns
    for job in failed_jobs:
        job_log = self._extract_job_log(log_content, job['id'])
        errors = self._parse_log_errors(job_log)
        # Add errors to analysis
```

**Pros**:
- Rich error details
- Actual error messages
- Better error type detection

**Cons**:
- Logs expire after 90 days
- Additional API call
- Larger Lambda package (zipfile)
- More processing time

### Option 3: Use GitHub API Annotations (Advanced)

**What**: Fetch annotations from failed steps

**API Endpoint**: `/repos/{owner}/{repo}/check-runs/{check_run_id}/annotations`

**Pros**:
- Structured error data
- Doesn't expire like logs

**Cons**:
- Only available for check runs
- More complex API integration
- May not cover all failure types

### Option 4: Enhanced Step Analysis (Recommended Hybrid)

**What**: Combine multiple approaches

**Implementation Strategy**:
1. **Always**: Parse step names and status (Option 1)
2. **When available**: Fetch and parse logs (Option 2)
3. **Fallback**: Use job-level error messages if available

```python
def analyze(self, workflow_run, jobs, logs_zip=None):
    # Always analyze steps from jobs data
    job_analyses = []
    for job in failed_jobs:
        analysis = self._analyze_job(job)
        
        # Enhance with logs if available
        if logs_zip:
            job_logs = self._extract_job_logs(logs_zip, job['id'])
            analysis['log_errors'] = self._parse_log_errors(job_logs)
            analysis['error_type'] = self._identify_error_type_from_logs(job_logs)
        
        job_analyses.append(analysis)
```

## Recommended Approach

**Phase 1 (Immediate)**: Enhance step analysis
- Parse step names more thoroughly
- Check step status fields
- Extract error patterns from step names

**Phase 2 (Next)**: Add log parsing
- Fetch logs when available
- Parse logs for error messages
- Handle log expiration gracefully

**Phase 3 (Future)**: Add annotations support
- Fetch check run annotations
- Parse structured error data

## Implementation Priority

1. ✅ **Immediate**: Enhance `_analyze_step()` to parse step names better
2. ⏳ **Next**: Add optional log fetching and parsing
3. 🔮 **Future**: Add annotations support

## Testing

To test enhanced error detection:
1. Use a recent workflow run (< 90 days old)
2. Verify logs are available
3. Compare analysis with and without logs
4. Test with various error types

