# Lambda Deployment Fix - Step by Step

## Problem
Lambda function is still logging full event ("Received event: {...}") even after local code was updated.

## Solution
Fixed end-to-end: code → packaging → Terraform → deployment

---

## Files Changed

### 1. `src/lambda_handler.py`
**Change**: Updated log message to use "SANITIZED_REQUEST" prefix
- **Why**: Makes it easy to verify in logs that sanitized logging is active
- **What**: Changed `logger.info("Request: %s", safe)` to `logger.info("SANITIZED_REQUEST: %s", safe)`

### 2. Files Verified (No Changes Needed)
- **`scripts/package-lambda.sh`**: ✅ Correctly packages `src/` directory
- **`terraform/modules/lambda/main.tf`**: ✅ Has `source_code_hash = filebase64sha256(local.lambda_zip_path)` which forces updates

---

## Verification Steps

Run these commands in order:

### Step 1: Run Tests
```bash
cd /Users/oluwabamiseomolaso/coding_projects/deploymentor
pytest -q
```
**Expected**: All tests pass

### Step 2: Package Lambda Function
```bash
./scripts/package-lambda.sh
```
**Expected**: 
- Creates `lambda_function.zip`
- Shows package size
- No errors

### Step 3: Verify Package Contains Updated Code
```bash
unzip -l lambda_function.zip | grep lambda_handler.py
unzip -p lambda_function.zip src/lambda_handler.py | grep -A 5 "SANITIZED_REQUEST"
```
**Expected**: 
- `lambda_handler.py` is in the zip
- Contains "SANITIZED_REQUEST" log message
- No "Received event" found

### Step 4: Terraform Plan
```bash
cd terraform
terraform plan -var="environment=prod"
```
**Expected**: 
- Shows `aws_lambda_function.this` will be updated
- `source_code_hash` changed (forces update)

### Step 5: Terraform Apply
```bash
terraform apply -var="environment=prod" -auto-approve
```
**Expected**: 
- Lambda function updates successfully
- No errors

### Step 6: Test Health Endpoint
```bash
curl https://ed8x9ozz8f.execute-api.us-east-1.amazonaws.com/health
```
**Expected**: Returns `{"status":"healthy",...}`

### Step 7: Check Lambda Logs
```bash
aws logs tail "/aws/lambda/deploymentor-prod" --since 10m --follow
```
**Expected**: 
- Logs show `SANITIZED_REQUEST: {'path': '/health', 'httpMethod': 'GET', 'requestId': '...'}`
- **NO** "Received event: {...}" log lines
- No full event JSON in logs

---

## Quick Verification Script

Run this to verify everything:

```bash
#!/bin/bash
set -e

echo "1️⃣ Running tests..."
pytest -q || exit 1

echo ""
echo "2️⃣ Packaging Lambda..."
./scripts/package-lambda.sh || exit 1

echo ""
echo "3️⃣ Verifying package contains SANITIZED_REQUEST..."
if unzip -p lambda_function.zip src/lambda_handler.py | grep -q "SANITIZED_REQUEST"; then
    echo "   ✅ Package contains sanitized logging"
else
    echo "   ❌ Package missing sanitized logging!"
    exit 1
fi

echo ""
echo "4️⃣ Checking Terraform plan..."
cd terraform
terraform plan -var="environment=prod" | grep -q "aws_lambda_function.this" && echo "   ✅ Lambda will be updated" || echo "   ⚠️  Lambda update not detected"

echo ""
echo "✅ Verification complete! Ready to deploy."
```

---

## Expected Log Output

**Before (Bad)**:
```
INFO Received event: {"requestContext": {...}, "headers": {...}, "body": {...}}
```

**After (Good)**:
```
INFO SANITIZED_REQUEST: {'path': '/health', 'httpMethod': 'GET', 'requestId': 'abc123...'}
```

---

## Troubleshooting

### If logs still show "Received event":
1. **Check package**: `unzip -p lambda_function.zip src/lambda_handler.py | grep "Received event"`
   - If found: packaging didn't include updated code
   - Fix: Re-run `./scripts/package-lambda.sh`

2. **Check Terraform**: `cd terraform && terraform plan -var="environment=prod"`
   - If no Lambda update: `source_code_hash` might not be working
   - Fix: Manually update Lambda: `aws lambda update-function-code --function-name deploymentor-prod --zip-file fileb://../lambda_function.zip`

3. **Check deployment**: Verify Terraform actually applied
   - Check: `terraform show | grep source_code_hash`
   - Re-apply if needed: `terraform apply -var="environment=prod"`

### If source_code_hash not updating:
- Ensure `lambda_function.zip` is regenerated before `terraform apply`
- Check file modification time: `ls -lh lambda_function.zip`
- Terraform compares hash, so zip must change for update to trigger

---

**Last Updated**: March 4, 2026

