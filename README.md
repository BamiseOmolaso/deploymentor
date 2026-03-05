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

## 🚀 Quick Start

### Prerequisites

- Python 3.12+
- Terraform >= 1.5.0
- AWS CLI configured
- GitHub Personal Access Token

### 1. Clone and Setup

```bash
git clone https://github.com/BamiseOmolaso/deploymentor.git
cd deploymentor
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
```

### 2. Configure GitHub Token

Store your GitHub token in AWS SSM:

```bash
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "your-token-here" \
  --type "SecureString" \
  --region us-east-1
```

See [SSM Setup Guide](docs/SSM_SETUP.md) for details.

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### 4. Test the API

```bash
# Health check
curl https://YOUR_API_URL/health

# Analyze a workflow
curl -X POST https://YOUR_API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "your-username",
    "repo": "your-repo",
    "run_id": 123456789
  }'
```

See [API Usage Guide](docs/API_USAGE.md) for more examples.

## 🚀 Quick Start (Old)

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

## 💰 Cost Estimate

Target: **$5-10/month**
- Lambda: ~$0.20 (1M requests)
- API Gateway: ~$1.00 (1M requests)
- CloudWatch: ~$0.50 (logs)
- SSM Parameter Store: Free tier
- **Total**: ~$1.70/month (well under budget)

## 📚 Documentation

- [Architecture](./docs/ARCHITECTURE.md)
- [Deployment Guide](./docs/DEPLOYMENT.md)
- [Security Practices](./docs/SECURITY.md)
- [Development Guide](./docs/DEVELOPMENT.md)

## 📝 License

MIT License - See [LICENSE](./LICENSE) file
