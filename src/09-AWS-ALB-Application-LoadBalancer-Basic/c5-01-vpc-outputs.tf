output "default_vpc_id" {
  description = "The ID of the default VPC"
  value = data.aws_vpc.default_vpc.id
}

output "default_vpc_arn" {
  description = "the ARN of the default VPC"
  value = data.aws_vpc.default_vpc.arn
}

output "default_vpc_enable_dns_support" {
  description = "enable_dns_hostnames of the default VPC"
  value = data.aws_vpc.default_vpc.enable_dns_support
}

output "default_vpc_enable_dns_hostnames" {
  description = "enable_dns_support of the default VPC"
  value = data.aws_vpc.default_vpc.enable_dns_hostnames
}

output "default_vpc_instance_tenancy" {
  description = "instance_tenancy of the default VPC"
  value = data.aws_vpc.default_vpc.instance_tenancy
}


output "default_vpc_main_route_table_id" {
  description = "main_route_table_id of the default VPC"
  value = data.aws_vpc.default_vpc.main_route_table_id
}

output "default_vpc_default_cidr_block" {
  description = "the CIDR block of the default VPC"
  value = data.aws_vpc.default_vpc.cidr_block
}