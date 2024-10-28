# EC2 Instance
resource "aws_instance" "terraform-ec2-04-ec2" {
  ami = data.aws_ami.terraform-ec2-04-aws_ami.id
  instance_type = var.instance_type
  user_data = file("${path.module}/app1-install.sh")
  key_name = var.instance_keypair
  vpc_security_group_ids = [aws_security_group.default-vpc-ssh.id, aws_security_group.default-vpc-web.id]
  tags = {
    "Name" = "EC2 Demo 2"
  }
}