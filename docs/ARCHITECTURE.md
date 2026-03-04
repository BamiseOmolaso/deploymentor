# DeployMentor Architecture

## Overview

DeployMentor is a serverless application that analyzes failed GitHub Actions workflow runs. The architecture follows AWS serverless best practices with a focus on security, cost optimization, and maintainability.

## Architecture Diagram

```
┌─────────────────┐
│  GitHub Actions │
│   (Webhook)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  API Gateway     │
│  HTTP API        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  AWS Lambda      │
│  (Python 3.12)   │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌──────────────┐
│ GitHub │ │ SSM Parameter│
│  API   │ │    Store     │
└────────┘ └──────────────┘
```

## Components

### API Gateway HTTP API
- **Purpose**: Entry point for all requests
- **Type**: HTTP API (cheaper than REST API)
- **Features**:
  - CORS configuration
  - Access logging to CloudWatch
  - Auto-deploy on changes

### AWS Lambda
- **Runtime**: Python 3.12
- **Memory**: 256 MB (default, adjustable)
- **Timeout**: 30 seconds
- **Permissions**: Least privilege IAM role
  - CloudWatch Logs write
  - SSM Parameter Store read (only `/deploymentor/*`)

### SSM Parameter Store
- **Purpose**: Secure storage for secrets
- **Parameters**:
  - `/deploymentor/github/token` - GitHub personal access token
- **Type**: SecureString (encrypted)

### CloudWatch
- **Logs**: Lambda execution logs, API Gateway access logs
- **Retention**: 7 days (cost optimization)
- **Metrics**: Automatic Lambda metrics

## Security Architecture

### Authentication & Authorization
- **GitHub API**: Uses personal access token from SSM
- **AWS Access**: GitHub Actions uses OIDC (no access keys)
- **IAM**: Least privilege principle

### Secrets Management
- **No hardcoded secrets** in code or Terraform
- All secrets stored in SSM Parameter Store
- Lambda retrieves secrets at runtime

### Network Security
- API Gateway is public (by design)
- No VPC required (keeps costs low)
- CORS configured for API access

## Cost Optimization

### Current Estimates (per month)
- **Lambda**: ~$0.20 (1M requests @ 256MB, 100ms avg)
- **API Gateway**: ~$1.00 (1M requests)
- **CloudWatch Logs**: ~$0.50 (7-day retention)
- **SSM Parameter Store**: Free tier
- **Total**: ~$1.70/month

### Cost Controls
- 7-day log retention (vs default 30 days)
- HTTP API (cheaper than REST API)
- Minimal Lambda memory allocation
- No VPC (reduces cold start time and cost)

## Scalability

- **Automatic scaling**: Lambda scales automatically
- **Concurrent executions**: Default limit (1000) sufficient for MVP
- **API Gateway**: Handles millions of requests

## Monitoring & Observability

- **CloudWatch Logs**: All Lambda executions logged
- **CloudWatch Metrics**: Automatic Lambda metrics
- **API Gateway Logs**: Access logs for debugging
- **Health endpoint**: `/health` for monitoring

## Future Enhancements

- Add CloudWatch Alarms for error rates
- Implement request rate limiting
- Add X-Ray tracing for distributed tracing
- Consider Step Functions for complex workflows

