data "aws_subnets" "public_subnets" {

  tags = {
    Public = true
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}