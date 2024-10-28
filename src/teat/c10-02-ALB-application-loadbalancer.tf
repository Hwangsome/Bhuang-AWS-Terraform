# Terraform AWS Application Load Balancer (ALB)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  #version = "5.16.0"
  version = "9.4.0"

  name = "${local.name}-alb"
  load_balancer_type = "application"
  vpc_id = data.aws_vpc.default.id
  subnets = data.aws_subnets.public_subnets.ids
  #security_groups = [module.loadbalancer_sg.this_security_group_id]
#  create_security_group = false
#  security_groups = [module.loadbalancer_sg.security_group_id]
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  # For example only
  enable_deletion_protection = false

# Listeners
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

# Target Groups 。 Target Groups 这个默认在 "terraform-aws-modules/alb/aws" 中是创建的
#  他的源码是：for_each = { for k, v in var.target_groups : k => v if local.create }  local.create 的默认值是 true
  target_groups = {
   # Target Group-1: mytg1
   mytg1 = {
      # VERY IMPORTANT: We will create aws_lb_target_group_attachment resource separately when we use create_attachment = false, refer above GitHub issue URL.
      ## Github ISSUE: https://github.com/terraform-aws-modules/terraform-aws-alb/issues/316
      ## Search for "create_attachment" to jump to that Github issue solution
      create_attachment = false
      name_prefix                       = "mytg1-"
      protocol                          = "HTTP"
      target_type                       = "lambda"
      deregistration_delay              = 10
      load_balancing_cross_zone_enabled = false
      protocol_version = "HTTP1"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app1/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }# End of health_check Block
      tags = local.common_tags # Target Group Tags
    } # END of Target Group: mytg1
  } # END OF target_groups Block
  tags = local.common_tags # ALB Tags
}

# Load Balancer Target Group Attachment
#resource "aws_lb_target_group_attachment" "mytg1" {
#  for_each = {for k, v in module.ec2_private: k => v}
#  target_group_arn = module.alb.target_groups["mytg1"].arn
#  target_id        = each.value.id
#  port             = 80
#}

resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function_alb.lambda_function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn = module.alb.target_groups["mytg1"].arn
}


resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = module.alb.target_groups["mytg1"].arn
  target_id        = module.lambda_function_alb.lambda_function_arn
  depends_on       = [aws_lambda_permission.with_lb]
}

