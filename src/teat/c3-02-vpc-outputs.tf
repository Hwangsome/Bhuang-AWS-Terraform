output "default_vpc_id" {
  description = "aws 默认的 vpc id"
  value       = data.aws_vpc.default.id
}
