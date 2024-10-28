output "public_subnets" {
  description = "The public subnets"
  value = data.aws_subnets.public_subnets.ids
}