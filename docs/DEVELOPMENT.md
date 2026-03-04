# Development Guide

## Local Setup

### Prerequisites
- Python 3.12+
- Docker & Docker Compose
- AWS CLI configured (for local testing)

### Installation

1. Clone repository:
```bash
git clone <repository-url>
cd deploymentor
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

4. Set up environment variables:
```bash
cp .env.example .env.local
# Edit .env.local with your values
```

### Running Locally

#### Option 1: Docker Compose
```bash
docker-compose up -d
docker-compose exec deploymentor bash
```

#### Option 2: Direct Python
```bash
export AWS_REGION=us-east-1
export GITHUB_TOKEN=your-token  # For local dev only
python -m pytest tests/
```

## Project Structure

```
deploymentor/
├── src/                    # Application code
│   ├── lambda_handler.py   # Main entry point
│   ├── analyzers/          # Workflow analysis logic
│   ├── github/             # GitHub API client
│   └── utils/              # Utilities (SSM, etc.)
├── terraform/              # Infrastructure code
├── tests/                  # Test files
└── docs/                   # Documentation
```

## Development Workflow

### 1. Make Changes
- Write code in `src/`
- Add tests in `tests/`
- Update Terraform in `terraform/`

### 2. Run Tests Locally
```bash
pytest tests/ -v
pytest tests/ --cov=src --cov-report=html
```

### 3. Format Code
```bash
black src/ tests/
isort src/ tests/
```

### 4. Lint Code
```bash
flake8 src/ tests/
mypy src/
```

### 5. Commit Changes
```bash
git add .
git commit -m "feat: add new feature"
git push
```

### 6. CI/CD Pipeline
- GitHub Actions runs automatically
- Tests, linting, security checks
- Auto-deploy on `main` branch

## Testing

### Unit Tests
```bash
pytest tests/unit/
```

### Integration Tests
```bash
pytest tests/integration/
```

### Test Coverage
```bash
pytest --cov=src --cov-report=term-missing
```

## Code Style

### Python
- Follow PEP 8
- Use Black for formatting (line length: 100)
- Type hints where possible
- Docstrings for all functions

### Terraform
- Use `terraform fmt` before committing
- Follow Terraform best practices
- Document variables and outputs

## Debugging

### Local Lambda Testing
```bash
# Install SAM CLI (optional)
sam local invoke -e events/test-event.json
```

### CloudWatch Logs
```bash
aws logs tail /aws/lambda/deploymentor-prod --follow
```

### API Gateway Testing
```bash
# Get API URL
cd terraform && terraform output api_gateway_url

# Test endpoint
curl $(terraform output -raw api_gateway_url)/health
```

## Adding New Features

### 1. Create Feature Branch
```bash
git checkout -b feature/new-feature
```

### 2. Implement Feature
- Write code
- Add tests
- Update documentation

### 3. Test Locally
```bash
pytest tests/
black src/ tests/
flake8 src/ tests/
```

### 4. Create Pull Request
- PR will trigger CI checks
- Review and merge when ready

### 5. Deploy
- Merging to `main` triggers deployment
- Monitor CloudWatch Logs

## Environment Variables

### Local Development
Create `.env.local` (gitignored):
```
AWS_REGION=us-east-1
GITHUB_TOKEN=your-token-here
LOG_LEVEL=DEBUG
ENVIRONMENT=dev
```

### Lambda Environment
Set in Terraform `variables.tf`:
- `ENVIRONMENT`
- `GITHUB_TOKEN_SSM_PARAM`
- `LOG_LEVEL`

## Common Tasks

### Update Dependencies
```bash
pip install --upgrade package-name
pip freeze > requirements.txt
```

### Update Lambda Function
```bash
cd src
zip -r ../lambda_function.zip .
aws lambda update-function-code \
  --function-name deploymentor-prod \
  --zip-file fileb://../lambda_function.zip
```

### View Terraform Plan
```bash
cd terraform
terraform plan -var="environment=prod"
```

## Troubleshooting

### Import Errors
- Check `PYTHONPATH` is set correctly
- Verify virtual environment is activated

### AWS Credentials
- Run `aws configure`
- Check credentials: `aws sts get-caller-identity`

### Docker Issues
- Rebuild: `docker-compose build --no-cache`
- Check logs: `docker-compose logs`

## Resources

- [AWS Lambda Python Docs](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

