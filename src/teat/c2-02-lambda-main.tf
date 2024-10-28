
# Lambda Function (store package locally)
module "lambda_function_alb" {
  source = "terraform-aws-modules/lambda/aws"
  version = "7.10.0"
  function_name = "my-lambda1"
  description   = "My awesome lambda function"
  handler       = "awesome-lambda.lambda_handler"
  runtime       = "python3.12"

#  这个参数是指定lambda 函数具有 将执行失败的事件发送到队列的权限
#   actions = ["sns:Publish","sqs:SendMessage"]
  attach_dead_letter_policy = true
  dead_letter_target_arn = aws_sqs_queue.lambda_dlq.arn

  source_path = "${path.module}/lambda"

#  add trigger
  allowed_triggers = {
    CloudwatchTriggerLambdaFunctionRule = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.lambda_rule.arn
    }
  }

#  to solve the issue: operation error Lambda: AddPermission, https response error StatusCode: 400, RequestID: 6e47233a-dd08-4267-8760-05b1113ea0f9, InvalidParameterValueException: We currently do not support adding policies for $LATEST.
# https://github.com/terraform-aws-modules/terraform-aws-lambda/issues/36
  create_current_version_allowed_triggers = false

#  lambda tags
  tags = {
    Name = "my-lambda1"
  }
}



