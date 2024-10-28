# EC2 Instance
# aws_instance.myec2vm["1a"]
# aws_instance.myec2vm["1b"]
# aws_instance.myec2vm["1c"]
resource "aws_instance" "myec2vm" {
  for_each = toset(["1a", "1b", "1c"])
  ami = data.aws_ami.terraform-ec2-04-aws_ami.id
  instance_type = var.instance_type
  user_data = file("${path.module}/app1-install.sh")
  key_name = var.instance_keypair
  vpc_security_group_ids = [ aws_security_group.vpc-ssh.id, aws_security_group.vpc-web.id   ]
  tags = {
    "Name" = "Count-Demo-${each.key}"
  }
}

/*
# Drawbacks of using count in this example
- Resource Instances in this case were identified using index numbers 
instead of string values like actual subnet_id
- If an element was removed from the middle of the list, 
every instance after that element would see its subnet_id value 
change, resulting in more remote object changes than intended. 
- Even the subnet_ids should be pre-defined or we need to get them again 
using for_each or for using various datasources
- Using for_each gives the same flexibility without the extra churn.
*/