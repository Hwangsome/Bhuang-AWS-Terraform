resource "random_pet" "this" {
  length = 2
}


module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"
  bucket = local.bucket_name
  force_destroy = true
}


module "s3-bucket_notification" {
  source  = "terraform-aws-modules/s3-bucket/aws//modules/notification"
  version = "4.1.2"
  bucket = module.s3-bucket.s3_bucket_id

  eventbridge = true

  # Common error - Error putting S3 notification configuration: InvalidArgument: Configuration is ambiguously defined. Cannot have overlapping suffixes in two rules if the prefixes are overlapping for the same event type.

  lambda_notifications = {
    lambda1 = {
      function_arn  = module.lambda_function_alb.lambda_function_arn
      function_name = module.lambda_function_alb.lambda_function_name
      events        = ["s3:ObjectCreated:Put"]
      filter_prefix = "prefix/"
      filter_suffix = ".json"
    }
  }
}