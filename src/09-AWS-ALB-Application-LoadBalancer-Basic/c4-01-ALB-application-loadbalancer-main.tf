module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.11.0"
  name = "my-alb"
  internal = false
  ip_address_type = "ipv4"

  enable_deletion_protection = false

#  创建的ALB 位于哪个vpc
  vpc_id = data.aws_vpc.default_vpc.id
# 创建的ALB 的安全组
#  这个module 会 创建一个默认的空安全组， 这里需要我们手动attach 一个alb的安全组，允许80端口的访问
#  security_groups = []

# 创建的ALB 的 http监听器
  listeners = {
    # Listener-1: my-http-listener
    my-http-listener = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "mytg1"
      }
    }# End of my-http-listener
  }# End of listeners block

#
  target_groups = {
    mytg1 = {
      name_prefix = "mytg1-" # Optional, creates a unique name beginning with the specified prefix.
      protocol_version    = "HTTP1"
      port        = 80
      target_type = "instance"
      ip_address_type = "ipv4"
      vpc_id = data.aws_vpc.default_vpc.id
      target_id = module.private_ec2_instance.id

      health_check = {
        enabled             = true
        path                = "/"
        port                = "80"
        protocol            = "HTTP"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
      }
    }
  }

#  选择至少两个可用区（Availability Zones）和每个区域至少一个子网（subnet）。
#  负载均衡器仅将流量路由到这些可用区中的目标。负载均衡器或VPC不支持的可用区无法选择。
  subnets = data.aws_subnets.default_vpc_public_subnets.ids

}

# Load Balancer Target Group Attachment
#resource "aws_lb_target_group_attachment" "mytg1" {
#  depends_on = [module.private_ec2_instance]
#//  for_each = {for k, v in module.private_ec2_instance: k => v}
#  target_group_arn = module.alb.target_groups["mytg1"].arn
#  target_id        = module.private_ec2_instance.id
# // each.value.id
#
#  port             = 80
#}
