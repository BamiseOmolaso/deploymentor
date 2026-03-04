# Deployment Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.5.0 installed
3. **AWS CLI** configured
4. **GitHub Repository** with Actions enabled
5. **GitHub Personal Access Token** (for GitHub API access)

## Step 1: Create SSM Parameter

First, store your GitHub token securely:

```bash
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "your-github-token-here" \
  --type "SecureString" \
  --region us-east-1
```

**Security Note**: Never commit this token to git!

## Step 2: Configure GitHub OIDC

### Create IAM Role for GitHub Actions

1. Create a trust policy file `github-oidc-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/deploymentor:*"
        }
      }
    }
  ]
}
```

2. Create the IAM role:

```bash
aws iam create-role \
  --role-name GitHubActionsDeployMentorRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json
```

3. Attach deployment policy (create policy with Terraform deploy permissions):

```bash
# Policy will be created by Terraform, or create manually
```

4. Configure GitHub Secret:
   - Go to GitHub repository → Settings → Secrets and variables → Actions
   - Add secret: `AWS_ROLE_ARN` = `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsDeployMentorRole`

### Create OIDC Provider (if not exists)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## Step 3: Configure Terraform Backend (Optional)

For production, use S3 backend for Terraform state:

1. Create S3 bucket for state:
```bash
aws s3 mb s3://deploymentor-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket deploymentor-terraform-state \
  --versioning-configuration Status=Enabled
```

2. Update `terraform/main.tf` backend configuration

## Step 4: Deploy Infrastructure

### Local Deployment (for testing)

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

### CI/CD Deployment

Push to `main` branch - GitHub Actions will deploy automatically.

## Step 5: Verify Deployment

1. Get API URL:
```bash
cd terraform
terraform output api_gateway_url
```

2. Test health endpoint:
```bash
curl $(terraform output -raw api_gateway_url)/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "deploymentor",
  "version": "0.1.0"
}
```

## Step 6: Update Lambda Code

After making code changes:

```bash
# Package Lambda
cd src
zip -r ../lambda_function.zip .
cd ..

# Update Lambda function
aws lambda update-function-code \
  --function-name deploymentor-prod \
  --zip-file fileb://lambda_function.zip
```

Or let CI/CD handle it automatically.

## Troubleshooting

### Lambda Function Not Found
- Check function name matches Terraform output
- Verify deployment completed successfully

### SSM Parameter Not Found
- Verify parameter exists: `aws ssm get-parameter --name "/deploymentor/github/token"`
- Check Lambda IAM role has SSM read permissions

### API Gateway 502 Error
- Check CloudWatch Logs for Lambda errors
- Verify Lambda function is deployed
- Check Lambda timeout settings

### OIDC Authentication Fails
- Verify GitHub OIDC provider exists
- Check IAM role trust policy
- Verify GitHub secret `AWS_ROLE_ARN` is set correctly

## Rollback

To rollback to previous version:

```bash
cd terraform
terraform plan -destroy
# Review changes
terraform apply
```

Or redeploy previous Lambda version from AWS Console.

## Cost Monitoring

Monitor costs in AWS Cost Explorer:
- Filter by tag: `Project=DeployMentor`
- Set up billing alerts for budget threshold

