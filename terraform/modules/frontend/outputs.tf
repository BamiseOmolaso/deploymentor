output "frontend_url" {
  description = "CloudFront URL for the frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for frontend files"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = aws_cloudfront_distribution.frontend.id
}
