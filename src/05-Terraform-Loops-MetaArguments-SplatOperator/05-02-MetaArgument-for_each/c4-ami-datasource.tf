# Get latest AMI ID for Amazon Linux2 OS
# Get Latest AWS AMI ID for Amazon2 Linux
data "aws_ami" "terraform-ec2-04-aws_ami" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = [ "al2023-*" ]
  }
  filter {
    name = "root-device-type"
    values = [ "ebs" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}