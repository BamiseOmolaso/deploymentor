# DeployMentor

> A serverless AI agent that analyzes failed GitHub Actions workflow runs and explains root cause and possible fixes.

<!-- Test PR to verify CI auto-triggers -->

## 🎯 Project Overview

DeployMentor is a serverless application built on AWS Lambda that:
- Analyzes failed GitHub Actions workflow runs
- Identifies root causes of failures
- Suggests actionable fixes
- Provides insights through a REST API

## 🏗️ Architecture

```
GitHub Actions → API Gateway HTTP API → AWS Lambda → AI Analysis → Response
```

**Infrastructure:**
- **Compute**: AWS Lambda (Python 3.12)
- **API**: API Gateway HTTP API
- **Secrets**: AWS Systems Manager Parameter Store
- **Monitoring**: CloudWatch Logs & Metrics
- **IaC**: Terraform
- **CI/CD**: GitHub Actions with OIDC

## 📚 Documentation

- **[🚀 Quick Start Guide](QUICKSTART.md)** - Deploy in under 10 minutes (recommended for first-time users)
- **[API Usage Guide](docs/API_USAGE.md)** - How to use the DeployMentor API
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Deploy infrastructure to AWS
- **[Code Promotion Guide](docs/PROMOTION_GUIDE.md)** - How to promote code through dev → staging → prod
- **[Branch Protection Setup](docs/BRANCH_PROTECTION_SETUP.md)** - Configure GitHub branch protection rules
- **[GitHub OIDC Setup](docs/GITHUB_OIDC_SETUP.md)** - Configure secure CI/CD with OIDC
- **[Security Practices](docs/SECURITY.md)** - Security best practices
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common errors and solutions
- **[Local Development](docs/LOCAL_DEVELOPMENT.md)** - Set up local development environment
- **[Testing Guide](docs/TESTING.md)** - How to test the API
- **[SSM Setup](docs/SSM_SETUP.md)** - Configure AWS SSM Parameter Store
- **[DevOps Audit Report](docs/DEVOPS_AUDIT_REPORT.md)** - Comprehensive DevOps best practices audit

## 📁 Project Structure

```
deploymentor/
├── src/                    # Python application code
│   ├── lambda_handler.py   # Main Lambda entry point
│   ├── analyzers/          # Workflow analysis logic
│   ├── github/             # GitHub API client
│   └── utils/              # Utility functions
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Main configuration
│   ├── variables.tf       # Variable definitions
│   ├── outputs.tf         # Output values
│   └── modules/           # Reusable modules
│       ├── lambda/        # Lambda function module
│       ├── api_gateway/   # API Gateway module
│       └── iam/           # IAM roles & policies
├── docker/                 # Docker configuration
│   └── Dockerfile         # Local development container
├── .github/                # GitHub configuration
│   └── workflows/         # CI/CD workflows
│       ├── ci.yml        # Continuous Integration
│       ├── deploy-dev.yml    # Dev deployment (auto on push)
│       ├── deploy-staging.yml # Staging deployment (manual/tag)
│       └── deploy-prod.yml    # Prod deployment (manual/tag with approval)
├── tests/                  # Test files
├── scripts/                # Utility scripts
├── .gitignore            # Git ignore rules
├── requirements.txt       # Python dependencies
├── docker-compose.yml     # Local development
└── README.md             # This file
```

## 🚀 Quick Start

**Want to deploy quickly?** → **[See QUICKSTART.md](QUICKSTART.md)** (10 steps, under 10 minutes)

**Want detailed instructions?** → Continue reading below

---

## 🔄 Code Flow

DeployMentor enforces a strict one-direction code flow:

```
main → staging → prod
```

**Dev (Automatic)**:
- Push to `main` → CI passes → Dev auto-deploys

**Staging (Manual Merge)**:
- Merge `main` into `staging` → Push to `staging` → Staging deploys (with ancestry check)

**Prod (Manual Merge + Approval)**:
- Merge `staging` into `prod` → Push to `prod` → Prod workflow runs → Manual approval required → Prod deploys (with ancestry check)

**Enforcement**:
- ✅ Ancestry checks verify commits passed through previous environments
- ✅ Branch protection prevents direct pushes (see [Branch Protection Setup](docs/BRANCH_PROTECTION_SETUP.md))
- ✅ Manual approval gate on prod deployments
- ❌ No shortcuts, no skipping environments, no direct pushes

See [Code Promotion Guide](docs/PROMOTION_GUIDE.md) for detailed instructions.

---

## 🚀 Deploy Your Own Copy

Follow these simple steps to deploy DeployMentor to your own AWS account. This guide assumes you're new to AWS, Terraform, and Python.

### 1. Prerequisites

Before you begin, make sure you have:

#### AWS Account
- Create a free AWS account at [aws.amazon.com](https://aws.amazon.com)
- You'll need permissions for: S3, Lambda, API Gateway, IAM, SSM Parameter Store, DynamoDB

#### AWS CLI
Install and configure the AWS CLI:

```bash
# Install AWS CLI (macOS)
brew install awscli

# Install AWS CLI (Linux)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (e.g., us-east-1), and Output format (json)

# Verify it works
aws sts get-caller-identity
```

**Expected output**: Your AWS account ID and user ARN.

#### Terraform
Install Terraform:

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform version
```

**Expected**: Terraform v1.5.0 or higher.

#### Python 3.12+
Check your Python version:

```bash
python3 --version
```

If you don't have Python 3.12+, install it:

```bash
# macOS (using pyenv - recommended)
brew install pyenv
pyenv install 3.12.0
pyenv global 3.12.0

# Or use Homebrew directly
brew install python@3.12

# Linux
sudo apt update
sudo apt install python3.12 python3.12-venv
```

**Verify**: `python3 --version` should show 3.12.0 or higher.

### 2. Quickstart (Local Setup)

Set up the project locally and verify everything works:

```bash
# Clone the repository
git clone https://github.com/BamiseOmolaso/deploymentor.git
cd deploymentor

# Create Python virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # macOS/Linux
# OR
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Run tests to verify everything works
pytest -q
```

**Expected**: All 41 tests should pass. If tests fail, see Troubleshooting section below.

### 3. Set Up GitHub Environments

**⚠️ IMPORTANT**: Before deploying, you must set up GitHub Environments manually. This enables the manual approval gate for production deployments.

See [docs/GITHUB_ENVIRONMENT_SETUP.md](docs/GITHUB_ENVIRONMENT_SETUP.md) for step-by-step instructions.

**Quick summary**:
1. Go to repository Settings → Environments
2. Create three environments: `development`, `staging`, `production`
3. Configure `production` with required reviewers (manual approval gate)
4. Add `AWS_ROLE_ARN` secret to each environment

### 4. Deploy (Terraform)

Deploy the infrastructure to AWS. The project uses a three-environment lifecycle (dev → staging → prod):

#### Phase 1: Bootstrap Backend

First, create the S3 bucket for Terraform state storage (modern Terraform uses `use_lockfile` instead of DynamoDB):

```bash
cd terraform/bootstrap

# Initialize Terraform
terraform init

# Create backend resources (S3 bucket for state + lock files)
terraform apply
```

**What this does**: Creates secure storage for Terraform state files. Modern Terraform uses `use_lockfile = true` which stores locks as `.tflock` files in S3 (no DynamoDB needed). You'll be prompted to confirm - type `yes`.

**Important**: The GitHub Actions IAM role must have `s3:DeleteObject` permission on the state bucket to release lock files.

**Note**: If you see "bucket already exists", edit `terraform/bootstrap/variables.tf` and change `state_bucket_name` to something unique.

#### Phase 2: Deploy Infrastructure

Now deploy the main application:

```bash
# Go back to main terraform directory
cd ../

# Initialize Terraform (migrates state to S3)
terraform init -migrate-state
# When prompted "Do you want to copy existing state?", type: yes

# Deploy infrastructure
terraform apply -var="environment=prod"
# Type: yes when prompted
```

**What this creates**:
- Lambda function (runs your code)
- API Gateway (HTTP API endpoint)
- IAM roles (permissions)
- CloudWatch logs (monitoring)

**Before deploying**, you need to store your GitHub token:

```bash
# Store GitHub Personal Access Token in AWS
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_your_token_here" \
  --type "SecureString" \
  --region us-east-1
```

Get a GitHub token: [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens). Create a token with `repo` scope.

#### Get Your API URL

After deployment completes, get your API URL for the environment:

```bash
# Dev environment
cd terraform/environments/dev
terraform output api_gateway_url

# Staging environment
cd ../staging
terraform output api_gateway_url

# Prod environment
cd ../prod
terraform output api_gateway_url
```

**Expected output**: `https://xxxxx.execute-api.us-east-1.amazonaws.com`

### 5. Test

Test that everything is working using the smoke test script:

```bash
# Test dev environment
./scripts/smoke-test.sh dev

# Test staging environment
./scripts/smoke-test.sh staging

# Test prod environment
./scripts/smoke-test.sh prod
```

Or test manually:

```bash
# Replace with your actual API URL from above
curl https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/health
```

**Expected response**:
```json
{"status":"healthy","service":"deploymentor","version":"0.1.0"}
```

#### View Logs

Check Lambda function logs:

```bash
# Dev environment
aws logs tail "/aws/lambda/deploymentor-dev" --since 10m

# Staging environment
aws logs tail "/aws/lambda/deploymentor-staging" --since 10m

# Prod environment
aws logs tail "/aws/lambda/deploymentor-prod" --since 10m
```

**Expected**: You should see log entries showing your health check request.

### 6. Cost Notes

DeployMentor is designed to be **low-cost** (~$1.73/month):

| Service | Monthly Cost |
|---------|--------------|
| Lambda (1M requests) | ~$0.20 |
| API Gateway (1M requests) | ~$1.00 |
| CloudWatch Logs | ~$0.50 |
| S3 Backend (state storage + lock files) | ~$0.02 |
| **Total** | **~$1.73/month** |

**AWS Free Tier** includes:
- 1M Lambda requests/month (free)
- 1M API Gateway requests/month (free)
- 5GB S3 storage (free)
- 5GB S3 storage (free) - includes state and lock files

For low usage, you may pay **$0/month** thanks to the free tier!

### 6. Troubleshooting

#### "pytest: command not found"
**Problem**: Virtual environment not activated or dependencies not installed.

**Solution**:
```bash
source venv/bin/activate  # Activate venv first
pip install -r requirements-dev.txt
pytest -q
```

#### "ModuleNotFoundError: No module named 'src'"
**Problem**: Running Python incorrectly.

**Solution**: Use `python -m` to run modules:
```bash
# Wrong: python src/lambda_handler.py
# Correct: python -m src.lambda_handler
```

#### "terraform init" asks about backend migration
**Problem**: Normal prompt when migrating from local to S3 backend.

**Solution**: Type `yes` when asked "Do you want to copy existing state to the new backend?"

#### "Error: No valid credential sources found"
**Problem**: AWS CLI not configured.

**Solution**:
```bash
aws configure
# Enter your AWS credentials
aws sts get-caller-identity  # Verify it works
```

#### "Error: S3 bucket already exists"
**Problem**: Bucket name is taken (must be globally unique).

**Solution**:
1. Edit `terraform/bootstrap/variables.tf`
2. Change `state_bucket_name = "deploymentor-terraform-state"` to something unique like `"deploymentor-terraform-state-yourname"`
3. Also update `terraform/main.tf` backend bucket name to match
4. Run `terraform apply` again

#### "Error: Backend configuration changed"
**Problem**: Need to migrate state to new backend.

**Solution**:
```bash
cd terraform
terraform init -migrate-state
# Type: yes when prompted
```

### 🔒 Security Note

**Important**: Never commit these files to git:
- `terraform.tfstate` or `terraform.tfstate.backup` (Terraform state files)
- `.env` (environment variables with secrets)
- `*.tfvars` (variable files with secrets)
- Any files containing AWS keys or tokens

**Always use**:
- AWS SSM Parameter Store for secrets (as shown in Step 3)
- Remote state backend (S3) for Terraform state
- Environment variables for local development (`.env` file, not committed)

The `.gitignore` file is already configured to prevent committing these files.

### Next Steps

- **Analyze a workflow**: See [API Usage Guide](docs/API_USAGE.md)
- **Set up CI/CD**: See [GitHub OIDC Setup](docs/GITHUB_OIDC_SETUP.md)
- **Monitor costs**: Check AWS Cost Explorer monthly


## 🔒 Security

- **No hardcoded secrets** - All secrets in SSM Parameter Store
- **Least privilege IAM** - Minimal required permissions
- **OIDC authentication** - No AWS access keys in GitHub
- **Security scanning** - Automated checks in CI

See [SECURITY.md](./docs/SECURITY.md) for security practices.


## 📚 Documentation

- [Architecture](./docs/ARCHITECTURE.md) - System architecture overview
- [Deployment Guide](./docs/DEPLOYMENT.md) - Detailed deployment instructions
- [Security Practices](./docs/SECURITY.md) - Security best practices
- [Development Guide](./docs/DEVELOPMENT.md) - Local development setup
- [Troubleshooting Guide](./docs/TROUBLESHOOTING.md) - Common errors and solutions
- [API Usage Guide](./docs/API_USAGE.md) - API endpoint documentation

## 📝 License

MIT License - See [LICENSE](./LICENSE) file
