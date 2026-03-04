# Security Practices

## Overview

DeployMentor follows DevSecOps best practices to ensure security throughout the development lifecycle.

## Secrets Management

### ✅ DO
- Store all secrets in AWS SSM Parameter Store
- Use SecureString type for sensitive values
- Retrieve secrets at runtime in Lambda
- Use environment variables for non-sensitive config

### ❌ DON'T
- Hardcode secrets in code
- Commit secrets to git
- Store secrets in Terraform variables files
- Use AWS access keys in GitHub Actions

## IAM Principles

### Least Privilege
- Lambda role has **only** the permissions it needs:
  - CloudWatch Logs write access
  - SSM Parameter Store read access (scoped to `/deploymentor/*`)

### Example IAM Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/deploymentor/*"
    }
  ]
}
```

## GitHub Actions Security

### OIDC Authentication
- Uses OpenID Connect (OIDC) for AWS authentication
- No AWS access keys stored in GitHub secrets
- Role assumption with temporary credentials

### Workflow Permissions
- Minimal permissions required:
  - `id-token: write` (for OIDC)
  - `contents: read` (for checkout)

## Code Security

### Dependency Scanning
- Safety check in CI pipeline
- Regular dependency updates
- Pin dependency versions

### Secret Scanning
- Pre-commit hooks check for hardcoded secrets
- CI pipeline validates no secrets in code
- Pattern matching for common secret formats

### Input Validation
- Validate all API inputs
- Sanitize user-provided data
- Rate limiting (future enhancement)

## Infrastructure Security

### Terraform Security
- No secrets in `.tfvars` files
- Use Terraform variables for configuration
- Remote state encryption (when using S3 backend)

### API Gateway Security
- CORS configuration (restrict in production)
- Request validation (future enhancement)
- Rate limiting (future enhancement)

## Security Checklist

Before deploying:
- [ ] No hardcoded secrets in code
- [ ] SSM parameters created and encrypted
- [ ] IAM roles follow least privilege
- [ ] GitHub OIDC configured
- [ ] Security scans pass in CI
- [ ] Dependencies are up to date
- [ ] Logs don't contain sensitive data

## Incident Response

### If Secrets Are Compromised
1. Rotate secrets immediately in SSM Parameter Store
2. Review CloudWatch Logs for unauthorized access
3. Rotate GitHub token
4. Review IAM access logs

### Security Monitoring
- Monitor CloudWatch Logs for errors
- Set up alerts for unusual activity
- Regular security audits

## Compliance

- Follows AWS Well-Architected Framework security pillar
- Implements defense in depth
- Regular security reviews

