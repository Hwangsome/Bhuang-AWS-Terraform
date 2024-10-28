resource "aws_sqs_queue" "lambda_dlq" {
  name                        = "lambda-dlq"
# lambda 的死信队列 必须设置为 非 Fifo 队列
  fifo_queue                  = var.fifo_queue
  delay_seconds               = var.delay_seconds
  max_message_size            = var.max_message_size
  message_retention_seconds   = var.message_retention_seconds
  receive_wait_time_seconds   = var.receive_wait_time_seconds
  content_based_deduplication = var.content_based_deduplication
  tags                        = {
    Environment = "lambda"
  }
}