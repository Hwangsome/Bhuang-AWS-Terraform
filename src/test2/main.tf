resource "aws_security_group" "sg" {
#  count = 2
  for_each = toset(["a", "b"])
  name        = var.sg_a
  description = "Allow inbound traffic"
}