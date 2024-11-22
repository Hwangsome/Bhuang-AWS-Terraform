#data "aws_vpc" "default_vpc" {
#  default = true
#}
#
#data "aws_subnets" "default_vpc_public_subnets" {
#  filter {
#    name   = "vpc-id"
#    values = [data.aws_vpc.default_vpc.id]
#  }
#  tags = {
#    Public = true
#  }
#}
#
#module "alb" {
#  source  = "terraform-aws-modules/alb/aws"
#  version = "~> 9.0"
#
#  name = "terraform-alb-for-ecs"
#
#  load_balancer_type = "application"
#
#  vpc_id  = data.aws_vpc.default_vpc.id
#  subnets = data.aws_subnets.default_vpc_public_subnets.ids
#
#  # For example only
#  enable_deletion_protection = false
#
#  # Security Group
#  security_group_ingress_rules = {
#    all_http = {
#      from_port   = 80
#      to_port     = 80
#      ip_protocol = "tcp"
#      cidr_ipv4   = "0.0.0.0/0"
#    }
#  }
#  security_group_egress_rules = {
#    all = {
#      ip_protocol = "-1"
#      cidr_ipv4 = data.aws_vpc.default_vpc.cidr_block
#    }
#  }
#
#  listeners = {
#    ex_http = {
#      port     = 80
#      protocol = "HTTP"
#
#      forward = {
#        target_group_key = "ex_ecs"
#      }
#    }
#  }
#
#  target_groups = {
#    ex_ecs = {
#      backend_protocol                  = "HTTP"
#      backend_port                      = 80
#      target_type                       = "ip"
#      deregistration_delay              = 5
#      load_balancing_cross_zone_enabled = true
#
#      health_check = {
#        enabled             = true
#        healthy_threshold   = 5
#        interval            = 30
#        matcher             = "200"
#        path                = "/"
#        port                = "traffic-port"
#        protocol            = "HTTP"
#        timeout             = 5
#        unhealthy_threshold = 2
#      }
#
#      # Theres nothing to attach here in this definition. Instead,
#      # ECS will attach the IPs of the tasks to this target group
#      create_attachment = false
#    }
#  }
#}

module "ecs-codepipeline" {
  source  = "cloudposse/ecs-codepipeline/aws"
  version = "0.34.2"
  # insert the 7 required variables here
  branch  = "master"
  ecs_cluster_name = "terraform-cluster"
  image_repo_name = "bhuang-devops/go-simplehttp-blue-green"
  region = "us-east-1"
  repo_name = "go-simplehttp-blue-green"
  repo_owner = "HwangSome"
  service_name = "terraform-test-task-definition"
}

