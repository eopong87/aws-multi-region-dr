output "primary_website_url" {
  description = "URL of the primary S3 static website (us-east-1). This is your live site."
  value       = "http://${aws_s3_bucket_website_configuration.primary.website_endpoint}"
}

output "secondary_website_url" {
  description = "URL of the secondary S3 static website (us-west-2). This is your standby site."
  value       = "http://${aws_s3_bucket_website_configuration.secondary.website_endpoint}"
}

output "primary_bucket_name" {
  description = "Name of the primary S3 bucket."
  value       = aws_s3_bucket.primary.id
}

output "secondary_bucket_name" {
  description = "Name of the secondary S3 bucket."
  value       = aws_s3_bucket.secondary.id
}

output "replication_role_arn" {
  description = "ARN of the IAM role used for S3 cross-region replication."
  value       = aws_iam_role.replication.arn
}

output "failover_domain" {
  description = "The Route 53 failover domain (only shown when Route 53 failover is enabled)."
  value       = var.enable_route53_failover ? "http://${var.domain_name}" : "Route 53 failover not enabled"
}