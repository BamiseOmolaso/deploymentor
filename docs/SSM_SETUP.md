# SSM Parameter Setup Guide

## Overview

This guide explains how to create and manage the GitHub token SSM parameter required for DeployMentor.

## Prerequisites

- AWS CLI installed and configured
- AWS credentials with SSM Parameter Store write permissions
- GitHub Personal Access Token

## Step 1: Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Set expiration (recommended: 90 days or custom)
4. Select scopes:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
5. Generate token and **copy it immediately** (you won't see it again)

## Step 2: Create SSM Parameter

### Option A: Using the Script (Recommended)

```bash
# Make script executable (if not already)
chmod +x scripts/setup-ssm-parameter.sh

# Run the script with your GitHub token
./scripts/setup-ssm-parameter.sh ghp_your_token_here
```

### Option B: Using AWS CLI Directly

```bash
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_your_token_here" \
  --type "SecureString" \
  --region us-east-1 \
  --description "GitHub Personal Access Token for DeployMentor"
```

### Option C: Using AWS Console

1. Go to AWS Systems Manager → Parameter Store
2. Click "Create parameter"
3. Name: `/deploymentor/github/token`
4. Type: `SecureString`
5. Value: Your GitHub token
6. Click "Create parameter"

## Step 3: Verify Parameter

```bash
# Verify parameter exists
aws ssm get-parameter \
  --name "/deploymentor/github/token" \
  --with-decryption \
  --region us-east-1

# Or use the script's verification command
aws ssm get-parameter --name /deploymentor/github/token --with-decryption --region us-east-1
```

Expected output:
```json
{
    "Parameter": {
        "Name": "/deploymentor/github/token",
        "Type": "SecureString",
        "Value": "ghp_...",
        "Version": 1,
        "LastModifiedDate": "2024-01-01T00:00:00.000Z",
        "ARN": "arn:aws:ssm:us-east-1:123456789012:parameter/deploymentor/github/token"
    }
}
```

## Step 4: Update Parameter (if needed)

If you need to rotate the token or update it:

```bash
# Using script
./scripts/setup-ssm-parameter.sh ghp_new_token_here

# Using AWS CLI
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_new_token_here" \
  --type "SecureString" \
  --overwrite \
  --region us-east-1
```

## Security Best Practices

1. **Never commit tokens to git** - Always use SSM Parameter Store
2. **Use SecureString type** - Ensures encryption at rest
3. **Rotate tokens regularly** - Update every 90 days or as needed
4. **Limit token permissions** - Only grant necessary scopes
5. **Monitor access** - Use CloudTrail to audit parameter access

## Troubleshooting

### Error: Parameter already exists

If you see this error, use the `--overwrite` flag:

```bash
aws ssm put-parameter \
  --name "/deploymentor/github/token" \
  --value "ghp_your_token" \
  --type "SecureString" \
  --overwrite \
  --region us-east-1
```

### Error: Access Denied

Ensure your AWS credentials have the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/deploymentor/*"
    }
  ]
}
```

### Error: Invalid token format

GitHub tokens typically start with `ghp_` (classic tokens) or `github_pat_` (fine-grained tokens). Ensure you copied the entire token.

## Cost

SSM Parameter Store Standard parameters are **free** (up to 10,000 parameters per account). SecureString parameters use AWS KMS encryption, which may incur minimal costs if using a custom KMS key (default AWS-managed key is free).

## Next Steps

After creating the SSM parameter:

1. Verify Lambda IAM role has read permissions (configured in Terraform)
2. Deploy infrastructure (Step 10)
3. Test the `/analyze` endpoint

## Related Documentation

- [AWS SSM Parameter Store Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

