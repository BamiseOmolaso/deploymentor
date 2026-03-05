# DeployMentor

> A serverless AI agent that analyzes failed GitHub Actions workflow runs and explains root cause and possible fixes.

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

- **[API Usage Guide](docs/API_USAGE.md)** - How to use the DeployMentor API
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Deploy infrastructure to AWS
- **[GitHub OIDC Setup](docs/GITHUB_OIDC_SETUP.md)** - Configure secure CI/CD with OIDC
- **[Security Practices](docs/SECURITY.md)** - Security best practices
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common errors and solutions
- **[Local Development](docs/LOCAL_DEVELOPMENT.md)** - Set up local development environment
- **[Testing Guide](docs/TESTING.md)** - How to test the API
- **[SSM Setup](docs/SSM_SETUP.md)** - Configure AWS SSM Parameter Store

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
│       └── deploy.yml    # Deployment workflow
├── tests/                  # Test files
├── scripts/                # Utility scripts
├── .gitignore            # Git ignore rules
├── requirements.txt       # Python dependencies
├── docker-compose.yml     # Local development
└── README.md             # This file
```

## 🚀 Deploy Your Own Copy

Follow these steps to deploy DeployMentor to your own AWS account.

### Prerequisites

Before you begin, ensure you have:

- **AWS Account** with appropriate permissions (S3, Lambda, API Gateway, IAM, SSM, DynamoDB)
- **AWS CLI** installed and configured (`aws configure`)
- **Terraform** >= 1.5.0 installed (`terraform version`)
- **Python** 3.12+ installed (`python3 --version`)
- **GitHub Personal Access Token** with `repo` scope (for analyzing private repos)

### Step-by-Step Deployment

#### Step 1: Clone the Repository

```bash
git clone https://github.com/BamiseOmolaso/deploymentor.git
cd deploymentor
```

#### Step 2: Set Up Python Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# OR
venv\Scripts\activate     # On Windows

# Install dependencies
pip install -r requirements-dev.txt
```

#### Step 3: Run Tests

Verify everything works locally:

```bash
pytest -q
```

**Expected**: All tests should pass (41 tests).

#### Step 4: Bootstrap Terraform Backend

Before deploying the main infrastructure, create the S3 bucket and DynamoDB table for Terraform state:

```bash
cd terraform/bootstrap

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create backend resources
terraform apply
```

**What this creates:**
- S3 bucket for Terraform state (with encryption and versioning)
- DynamoDB table for state locking (prevents concurrent modifications)

**Note**: The bucket name defaults to `deploymentor-terraform-state`. If this name is taken, edit `terraform/bootstrap/variables.tf` to use a unique name.

#### Step 5: Configure GitHub Token in AWS

Store your GitHub Personal Access Token in AWS SSM Parameter Store:

```bash
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_your_token_here" \
  --type "SecureString" \
  --region us-east-1
```

See [SSM Setup Guide](docs/SSM_SETUP.md) for detailed instructions.

#### Step 6: Deploy Main Infrastructure

```bash
# Navigate to main terraform directory
cd ../  # Back to terraform/

# Initialize Terraform (will migrate state to S3)
terraform init -migrate-state

# Review deployment plan
terraform plan -var="environment=prod"

# Deploy infrastructure
terraform apply -var="environment=prod"
```

**What this creates:**
- Lambda function
- API Gateway HTTP API
- IAM roles and policies
- CloudWatch log groups

#### Step 7: Test the API

Get your API URL from Terraform output:

```bash
terraform output api_url
```

Then test the health endpoint:

```bash
# Replace with your actual API URL
curl https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/health
```

**Expected response:**
```json
{"status":"healthy","service":"deploymentor","version":"0.1.0"}
```

#### Step 8: View Logs

Monitor Lambda function logs:

```bash
aws logs tail "/aws/lambda/deploymentor-prod" --since 10m --follow
```

You should see sanitized request logs like:
```
INFO SANITIZED_REQUEST: {'path': '/health', 'httpMethod': 'GET', 'requestId': '...'}
```

### Next Steps

- **Analyze a workflow**: See [API Usage Guide](docs/API_USAGE.md)
- **Set up CI/CD**: See [GitHub OIDC Setup](docs/GITHUB_OIDC_SETUP.md)
- **Monitor costs**: See Cost Notes section below

### Prerequisites

- Python 3.12+
- Terraform >= 1.5
- Docker & Docker Compose
- AWS CLI configured
- GitHub repository with Actions enabled

### Local Development

```bash
# Start local development environment
docker-compose up

# Run tests
pytest tests/

# Format code
black src/
```

### Deployment

See [DEPLOYMENT.md](./docs/DEPLOYMENT.md) for detailed deployment instructions.

## 🔒 Security

- **No hardcoded secrets** - All secrets in SSM Parameter Store
- **Least privilege IAM** - Minimal required permissions
- **OIDC authentication** - No AWS access keys in GitHub
- **Security scanning** - Automated checks in CI

See [SECURITY.md](./docs/SECURITY.md) for security practices.

## 💰 Cost Notes

DeployMentor is designed to stay within a **$5-10/month** budget.

### Monthly Cost Breakdown (Estimated)

| Service | Usage | Cost |
|---------|-------|------|
| **Lambda** | 1M requests, 128MB, 1s avg | ~$0.20 |
| **API Gateway** | 1M requests (HTTP API) | ~$1.00 |
| **CloudWatch Logs** | 5GB storage, 1M ingestion | ~$0.50 |
| **CloudWatch Metrics** | Standard metrics | Free |
| **SSM Parameter Store** | 1 parameter | Free |
| **S3 (Terraform State)** | <1GB storage | ~$0.02 |
| **DynamoDB (Locks)** | Pay-per-request | ~$0.01 |
| **Total** | | **~$1.73/month** |

### Cost Optimization Tips

1. **CloudWatch Log Retention**: Default is 7 days. Reduce to 3 days to save ~$0.20/month
   - Edit `terraform/modules/lambda/main.tf`: `log_retention_days = 3`

2. **Lambda Memory**: 128MB is sufficient for most workloads. Only increase if needed.

3. **API Gateway**: HTTP API is cheaper than REST API. Already using HTTP API.

4. **Free Tier**: AWS Free Tier includes:
   - 1M Lambda requests/month
   - 1M API Gateway requests/month
   - 5GB S3 storage
   - 25GB DynamoDB storage

### Monitoring Costs

Check your AWS bill monthly:
```bash
# View CloudWatch billing metrics
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

Or use AWS Cost Explorer in the console.

## 🔧 Troubleshooting

### Common Issues

#### "pytest: command not found"
**Problem**: pytest is not installed or virtual environment is not activated.

**Solution**:
```bash
source venv/bin/activate  # Activate venv
pip install -r requirements-dev.txt  # Install dependencies
pytest -q  # Run tests
```

#### "Python version mismatch"
**Problem**: Wrong Python version (need 3.12+).

**Solution**:
```bash
python3 --version  # Check version
# If < 3.12, install Python 3.12+
# macOS: brew install python@3.12
# Then: python3.12 -m venv venv
```

#### "terraform: command not found"
**Problem**: Terraform is not installed.

**Solution**:
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

#### "Error: No valid credential sources found"
**Problem**: AWS CLI is not configured.

**Solution**:
```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region, Output format
aws sts get-caller-identity  # Verify credentials
```

#### "Error: Backend configuration changed"
**Problem**: Terraform backend was updated but state wasn't migrated.

**Solution**:
```bash
cd terraform
terraform init -migrate-state
# Answer "yes" when prompted to migrate state
```

#### "Error: S3 bucket already exists"
**Problem**: Bucket name in bootstrap is already taken.

**Solution**:
1. Edit `terraform/bootstrap/variables.tf`
2. Change `state_bucket_name` to a unique name (e.g., `deploymentor-terraform-state-yourname`)
3. Run `terraform apply` again

#### "Error: ResourceAlreadyExistsException"
**Problem**: Resources already exist in AWS (from previous deployment).

**Solution**:
```bash
# Import existing resources
./scripts/terraform-import-existing.sh prod
# Then run terraform apply
```

#### "404 Not Found" from API Gateway
**Problem**: Lambda handler not receiving requests correctly.

**Solution**:
1. Check Lambda logs: `aws logs tail "/aws/lambda/deploymentor-prod" --since 10m`
2. Verify API Gateway integration: Check Terraform outputs
3. Test Lambda directly: `aws lambda invoke --function-name deploymentor-prod output.json`

#### "Error: Missing required field: owner"
**Problem**: API request is missing required fields.

**Solution**:
```bash
# Ensure request body includes all required fields
curl -X POST https://YOUR_API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "username",
    "repo": "repo-name",
    "run_id": 123456789
  }'
```

### Getting Help

- **Check logs**: `aws logs tail "/aws/lambda/deploymentor-prod" --since 1h`
- **Review documentation**: See [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- **Verify infrastructure**: `cd terraform && terraform show`
- **Test locally**: `pytest -v` to see detailed test output

## 📚 Documentation

- [Architecture](./docs/ARCHITECTURE.md) - System architecture overview
- [Deployment Guide](./docs/DEPLOYMENT.md) - Detailed deployment instructions
- [Security Practices](./docs/SECURITY.md) - Security best practices
- [Development Guide](./docs/DEVELOPMENT.md) - Local development setup
- [Troubleshooting Guide](./docs/TROUBLESHOOTING.md) - Common errors and solutions
- [API Usage Guide](./docs/API_USAGE.md) - API endpoint documentation

## 📝 License

MIT License - See [LICENSE](./LICENSE) file
