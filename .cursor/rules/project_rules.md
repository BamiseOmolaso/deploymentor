Project rules for DeployMentor.

Architecture rules
- Infrastructure must use Terraform only.
- Do not introduce AWS CDK.
- Prefer serverless architecture.
- Deploy only one service initially (modular monolith).
- No Kubernetes unless explicitly requested later.
- Docker may be used for local development.

Cost control
- Target monthly cost: $5–$10.
- Prefer Lambda, API Gateway HTTP API, and SSM Parameter Store.
- Avoid services that require fixed monthly costs.

DevSecOps rules
- No hardcoded secrets in the repository.
- Use environment variables or AWS SSM Parameter Store.
- IAM policies must follow least privilege.
- Sanitize logs before sending to any AI model.

Development workflow
- Implement small steps only.
- Avoid generating a full complex system at once.
- Explain why changes are made.

Monitoring
- Use CloudWatch Logs and basic alarms for monitoring.
- Set log retention to reduce costs.

CI/CD
- Use GitHub Actions for CI/CD.
- Use OIDC authentication instead of AWS access keys.

Code quality
- Write readable Python code.
- Include logging and error handling.
- Prefer simple and maintainable solutions.