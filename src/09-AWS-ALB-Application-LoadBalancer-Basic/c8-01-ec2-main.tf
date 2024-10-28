module "private_ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.0"
  name                   = "${var.environment}-vm"
  ami                    = data.aws_ami.terraform-ec2-07-aws_ami.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  user_data = file("${path.module}/app1-install.sh")
  tags = local.common_tags

  # BELOW CODE COMMENTED AS PART OF MODULE UPGRADE TO 5.5.0
  #vpc_security_group_ids = [module.private_sg.this_security_group_id]
  #instance_count         = var.private_instance_count
  #subnet_ids = [module.vpc.private_subnets[0],module.vpc.private_subnets[1] ]
  vpc_security_group_ids = [module.private_security-group.security_group_id]
//  for_each = toset(["0", "1"])
  subnet_id =  data.aws_subnets.default_vpc_private_subnets.ids[0]
}


module "public_ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.0"
  name                   = "${var.environment}-BastionHost"
  ami                    = data.aws_ami.terraform-ec2-07-aws_ami.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  #monitoring             = true
  subnet_id              = data.aws_subnets.default_vpc_public_subnets.ids[0]
  tags = local.common_tags
  vpc_security_group_ids = [module.public_bastion_sg.security_group_id]

}
