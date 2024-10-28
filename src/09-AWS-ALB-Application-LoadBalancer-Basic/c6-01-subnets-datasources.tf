data "aws_subnets" "default_vpc_public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
  tags = {
    Public = true
  }
}


data "aws_subnets" "default_vpc_private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
  tags = {
    Public = false
  }
}