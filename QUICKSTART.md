# DeployMentor - Quick Start Guide

Deploy DeployMentor to your AWS account in **under 10 minutes**.

**Prerequisites**: AWS account, AWS CLI configured, Terraform installed, Python 3.12+.

---

## 1. Clone the repo

```bash
git clone https://github.com/BamiseOmolaso/deploymentor.git
cd deploymentor
```

## 2. Create Python environment

```bash
python3 -m venv venv
source venv/bin/activate
```

## 3. Install dependencies

```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

## 4. Run tests

```bash
pytest -q
```

**Expected**: All 41 tests pass.

## 5. Configure AWS credentials

```bash
aws configure
aws sts get-caller-identity
```

**Expected**: Your AWS account ID and user ARN.

## 6. Bootstrap Terraform backend

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

**What this creates**:
- S3 bucket for Terraform state (encrypted, versioned)
- DynamoDB table for state locking (prevents concurrent modifications)

Type `yes` when prompted.

## 7. Deploy infrastructure

```bash
cd ..
terraform init -migrate-state
# Type: yes when prompted to migrate state
terraform apply -var="environment=prod"
# Type: yes when prompted
```

**What this creates**: Lambda function, API Gateway, IAM roles, CloudWatch logs.

**Note**: Before deploying, store your GitHub token (optional, only needed for analyzing private repos):

```bash
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_your_token_here" \
  --type "SecureString" \
  --region us-east-1
```

## 8. Get the API URL

```bash
terraform output api_gateway_url
```

**Expected**: `https://xxxxx.execute-api.us-east-1.amazonaws.com`

## 9. Test DeployMentor

```bash
curl <API_URL>/health
```

**Expected response**:
```json
{"status":"healthy","service":"deploymentor","version":"0.1.0"}
```

## 10. View logs

```bash
aws logs tail "/aws/lambda/deploymentor-prod" --since 10m
```

**Expected**: Log entries showing your health check request.

---

## 💰 Estimated Monthly Cost

DeployMentor is designed to be **low-cost** - estimated **under $1/month** for low usage:

| Service | Low Usage | High Usage (1M requests) |
|---------|-----------|-------------------------|
| Lambda | Free tier | ~$0.20 |
| API Gateway HTTP API | Free tier | ~$1.00 |
| CloudWatch Logs | ~$0.10 | ~$0.50 |
| S3 Backend (state) | ~$0.01 | ~$0.02 |
| DynamoDB (locks) | ~$0.01 | ~$0.01 |
| **Total** | **~$0.12/month** | **~$1.73/month** |

**AWS Free Tier** (first 12 months):
- 1M Lambda requests/month (free)
- 1M API Gateway requests/month (free)
- 5GB S3 storage (free)
- 25GB DynamoDB storage (free)

For low usage, you may pay **$0/month** thanks to the free tier!

---

## 🔒 Security Notes

**Never commit to git**:
- `terraform.tfstate` or `terraform.tfstate.backup` (Terraform state files)
- `.env` (environment variables with secrets)
- `*.tfvars` (variable files with secrets)
- Any files containing AWS keys or tokens

**Always use**:
- AWS SSM Parameter Store for secrets (see Step 7 above)
- Remote state backend (S3) for Terraform state
- Environment variables for local development (`.env` file, not committed)

The `.gitignore` file is already configured to prevent committing these files.

---

## Need More Help?

- **Detailed instructions**: See [README.md](README.md) for comprehensive deployment guide
- **Troubleshooting**: See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **API usage**: See [docs/API_USAGE.md](docs/API_USAGE.md)
