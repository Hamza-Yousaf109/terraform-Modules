output "bucket_id" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_region" {
  description = "The AWS region of the S3 bucket"
  value       = aws_s3_bucket.bucket.region
}

output "bucket_domain_name" {
  description = "The bucket regional domain name"
  value       = aws_s3_bucket.bucket.bucket_regional_domain_name
}
