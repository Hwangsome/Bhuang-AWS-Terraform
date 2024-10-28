output "cloud_watch_id" {
  description = "The ID of the CloudWatch Event Rule"
  value = aws_cloudwatch_event_rule.lambda_rule.id
}

output "cloud_watch_arn" {
  description = "The ARN of the CloudWatch Event Rule"
  value = aws_cloudwatch_event_rule.lambda_rule.arn
}