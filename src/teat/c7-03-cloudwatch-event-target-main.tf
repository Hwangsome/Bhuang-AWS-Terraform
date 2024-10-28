resource "aws_cloudwatch_event_rule" "lambda_rule" {

  name        = "trigger-lambda-function"
  description = "invoke lambda function to trigger the event"

#  The name or ARN of the event bus to associate with this rule. If you omit this, the default event bus is used.
  event_bus_name = "default"

#  The event pattern described a JSON object. At least one of schedule_expression or event_pattern is required.
#  See full documentation of Events and Event Patterns in EventBridge for details (https://docs.aws.amazon.com/zh_cn/eventbridge/latest/userguide/eb-events.html).
#  Note: The event pattern size is 2048 by default but it is adjustable up to 4096 characters
#  by submitting a service quota increase request. See Amazon EventBridge quotas for details.
  schedule_expression = "cron(0 0/10 * * ? *)"

}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
    rule      = aws_cloudwatch_event_rule.lambda_rule.name
    arn       = module.lambda_function_alb.lambda_function_arn
}
