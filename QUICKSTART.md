# Quick Start Guide

## 🎯 What We've Built

You now have a complete project scaffold for **DeployMentor** - a serverless AI agent that analyzes failed GitHub Actions workflows.

## 📁 Project Structure Overview

```
deploymentor/
├── src/                          # Python Lambda application
│   ├── lambda_handler.py         # Main entry point (✅ Basic health endpoint)
│   ├── github/client.py          # GitHub API client (✅ Scaffolded)
│   ├── utils/ssm.py              # SSM Parameter Store utilities (✅ Ready)
│   └── analyzers/                # Workflow analysis logic (⏳ To be implemented)
│
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                   # Main configuration (✅ Complete)
│   ├── modules/
│   │   ├── lambda/               # Lambda module (✅ Complete with IAM)
│   │   └── api_gateway/          # API Gateway module (✅ Complete)
│   └── terraform.tfvars.example  # Example config (✅ Template)
│
├── .github/workflows/             # CI/CD Pipelines
│   ├── ci.yml                    # CI with security checks (✅ Complete)
│   └── deploy.yml                # OIDC-based deployment (✅ Complete)
│
├── docker/                        # Local development
│   └── Dockerfile                # Development container (✅ Ready)
│
├── scripts/                       # Helper scripts
│   ├── setup-ssm-parameter.sh   # Create SSM parameter (✅ Ready)
│   └── package-lambda.sh         # Package Lambda (✅ Ready)
│
└── docs/                          # Documentation
    ├── ARCHITECTURE.md           # System architecture (✅ Complete)
    ├── SECURITY.md               # Security practices (✅ Complete)
    ├── DEPLOYMENT.md             # Deployment guide (✅ Complete)
    └── DEVELOPMENT.md            # Development guide (✅ Complete)
```

## ✅ What's Ready

### 1. **Infrastructure (Terraform)**
- ✅ Lambda function module with IAM roles (least privilege)
- ✅ API Gateway HTTP API module
- ✅ CloudWatch Logs configuration
- ✅ SSM Parameter Store integration
- ✅ Cost-optimized settings (7-day log retention)

### 2. **Application Code**
- ✅ Lambda handler with health endpoint
- ✅ GitHub API client (scaffolded)
- ✅ SSM utilities for secret retrieval
- ✅ Project structure for analyzers

### 3. **CI/CD Pipeline**
- ✅ GitHub Actions CI workflow
- ✅ Security scanning (hardcoded secrets check)
- ✅ Code quality checks (Black, Flake8, MyPy)
- ✅ Terraform validation
- ✅ Deployment workflow with OIDC

### 4. **Security**
- ✅ No hardcoded secrets
- ✅ Least privilege IAM policies
- ✅ OIDC authentication setup
- ✅ Security checks in CI

### 5. **Development Tools**
- ✅ Docker setup for local dev
- ✅ Test framework (pytest)
- ✅ Code formatting (Black, isort)
- ✅ Linting (Flake8, MyPy)

## 🚀 Next Steps

### Step 1: Set Up Secrets (5 minutes)

```bash
# Create GitHub Personal Access Token
# Go to: https://github.com/settings/tokens
# Create token with: repo, workflow permissions

# Store in SSM Parameter Store
./scripts/setup-ssm-parameter.sh ghp_your_token_here
```

### Step 2: Configure GitHub OIDC (10 minutes)

1. **Create OIDC Provider** (if not exists):
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. **Create IAM Role** for GitHub Actions:
   - See `docs/DEPLOYMENT.md` for detailed steps
   - Create trust policy allowing GitHub OIDC
   - Attach policy with Terraform deploy permissions

3. **Configure GitHub Secret**:
   - Repository → Settings → Secrets → Actions
   - Add: `AWS_ROLE_ARN` = your role ARN

### Step 3: Test Locally (5 minutes)

```bash
# Install dependencies
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Run tests
pytest tests/

# Format code
black src/ tests/
```

### Step 4: Deploy Infrastructure (10 minutes)

```bash
cd terraform

# Initialize Terraform
terraform init

# Review plan
terraform plan -var="environment=dev"

# Apply (creates Lambda, API Gateway, IAM roles)
terraform apply -var="environment=dev"

# Get API URL
terraform output api_gateway_url
```

### Step 5: Test Deployment

```bash
# Test health endpoint
curl $(cd terraform && terraform output -raw api_gateway_url)/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "deploymentor",
  "version": "0.1.0"
}
```

## 🎓 Learning Points

### Security Best Practices Implemented

1. **No Hardcoded Secrets**
   - All secrets in SSM Parameter Store
   - Lambda retrieves at runtime
   - CI checks prevent accidental commits

2. **Least Privilege IAM**
   - Lambda role only has:
     - CloudWatch Logs write
     - SSM Parameter read (scoped to `/deploymentor/*`)

3. **OIDC Authentication**
   - No AWS access keys in GitHub
   - Temporary credentials via role assumption
   - Scoped to specific repository

### Cost Optimization

- **7-day log retention** (vs default 30 days)
- **HTTP API** (cheaper than REST API)
- **Minimal Lambda memory** (256 MB)
- **No VPC** (reduces cold starts)

### Architecture Decisions

- **Modular Terraform** - Reusable modules
- **Serverless-first** - No servers to manage
- **Python 3.12** - Latest stable runtime
- **API Gateway HTTP API** - Cost-effective

## 📝 What's Next?

### Immediate Tasks
1. ✅ Project scaffolded
2. ⏳ Implement workflow analyzer logic
3. ⏳ Add AI integration (OpenAI/Anthropic)
4. ⏳ Create API endpoints for analysis
5. ⏳ Add error handling and retries

### Future Enhancements
- Add CloudWatch Alarms
- Implement request rate limiting
- Add X-Ray tracing
- Create admin dashboard
- Add webhook support

## 🔍 Verification Checklist

Before moving forward, verify:

- [ ] SSM parameter created (`/deploymentor/github/token`)
- [ ] GitHub OIDC configured
- [ ] Terraform can initialize
- [ ] Local tests pass
- [ ] Code formatting works
- [ ] CI pipeline runs successfully

## 📚 Documentation

- **Architecture**: `docs/ARCHITECTURE.md`
- **Security**: `docs/SECURITY.md`
- **Deployment**: `docs/DEPLOYMENT.md`
- **Development**: `docs/DEVELOPMENT.md`

## 🆘 Troubleshooting

### Terraform Errors
- Check AWS credentials: `aws sts get-caller-identity`
- Verify SSM parameter exists
- Check IAM permissions

### Lambda Errors
- Check CloudWatch Logs: `/aws/lambda/deploymentor-dev`
- Verify SSM parameter path matches
- Check Lambda IAM role permissions

### CI/CD Errors
- Verify GitHub OIDC setup
- Check `AWS_ROLE_ARN` secret
- Review workflow logs

## 💡 Tips

1. **Start Small**: Deploy to `dev` environment first
2. **Monitor Costs**: Set up AWS billing alerts
3. **Test Locally**: Use Docker Compose for development
4. **Review Logs**: CloudWatch Logs are your friend
5. **Iterate**: Build incrementally, test frequently

---

**Ready to build?** Start with implementing the workflow analyzer in `src/analyzers/`! 🚀

