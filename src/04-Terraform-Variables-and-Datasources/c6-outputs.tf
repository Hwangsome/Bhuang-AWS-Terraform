# Terraform Output Values
# 执行terrafrom apply 后，输出的值。 相当于 log
#Apply complete! Resources: 1 added, 0 changed, 0 destroyed.#
#Outputs:
#instance_publicdns = "ec2-44-223-101-19.compute-1.amazonaws.com"
#instance_publicip = "44.223.101.19"


output "instance_publicip" {
  description = "EC2 Instance Public IP"
  value = aws_instance.terraform-ec2-04-ec2.public_ip
}

output "instance_publicdns" {
  description = "EC2 Instance Public DNS"
  value = aws_instance.terraform-ec2-04-ec2.public_dns
}


output "centos7" {
  value = data.aws_ami.centos7.id
}