# EC2 Instance
resource "aws_instance" "myec2vm" {
  ami = data.aws_ami.terraform-ec2-04-aws_ami.id
  instance_type = var.instance_type
  #instance_type = var.instance_type_list[1]  # For List
  #nstance_type = var.instance_type_map["prod"]  # For Map
  user_data = file("${path.module}/app1-install.sh")
  key_name = var.instance_keypair
  vpc_security_group_ids = [ aws_security_group.vpc-ssh.id, aws_security_group.vpc-web.id   ]
#  count 是一个 Meta-Argument，用于告诉 Terraform 创建 2 个 EC2 实例。count 允许你根据给定的数字创建多个相同的资源实例。
  count = 2
  tags = {
#    count.index 是 count 的内置变量，表示当前迭代的索引，从 0 开始。在每个 EC2 实例的 tags 中，它被用来为每个实例生成一个唯一的名字。
#    例如，第一个实例会有名称 "Count-Demo-0"，第二个实例会有名称 "Count-Demo-1"。
    "Name" = "Count-Demo-${count.index}"
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