output "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  value = module.s3-bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value = module.s3-bucket.s3_bucket_arn
}

output "s3_bucket_policy" {
  description = "The policy of the S3 bucket"
  value = module.s3-bucket.s3_bucket_policy
}