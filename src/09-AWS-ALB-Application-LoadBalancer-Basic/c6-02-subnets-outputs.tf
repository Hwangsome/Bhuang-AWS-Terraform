output "default_subnets_vpc_ids" {
  description = "The IDs of the default subnets in the VPC"
  value = data.aws_subnets.default_vpc_public_subnets.ids
}