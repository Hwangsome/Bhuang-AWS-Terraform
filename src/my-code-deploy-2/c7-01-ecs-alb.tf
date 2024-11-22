
data "aws_subnets" "default_vpc_public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
  tags = {
    Public = true
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name = "terraform-alb-for-ecs"

  load_balancer_type = "application"

  vpc_id  = data.aws_vpc.default_vpc.id
  subnets = data.aws_subnets.default_vpc_public_subnets.ids

  # For example only
  enable_deletion_protection = false

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }

    all_http_2 = {
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4 = data.aws_vpc.default_vpc.cidr_block
    }
  }

  listeners = {
    blue_http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "blue_env"
      }
    }

    green_http = {
      port     = 8080
      protocol = "HTTP"

      forward = {
        target_group_key = "green_env"
      }
    }
  }

  target_groups = {
    blue_env = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true
      name = "btg"

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }


#      在 AWS 的 ECS 集成中，ECS 服务可以通过 Application Load Balancer (ALB) 自动管理任务的 IP 地址。
#      具体来说，当您在 ECS 服务中指定了 target_group_arn（目标组的 ARN）后，ECS 会自动将每个运行中的任务实例的 IP 地址注册到该目标组中，
#      并根据任务的生命周期（启动、停止等）动态更新目标组中的 IP 地址。

      # Theres nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    },
    green_env = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true
      name = "gtg"
      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }


      #      在 AWS 的 ECS 集成中，ECS 服务可以通过 Application Load Balancer (ALB) 自动管理任务的 IP 地址。
      #      具体来说，当您在 ECS 服务中指定了 target_group_arn（目标组的 ARN）后，ECS 会自动将每个运行中的任务实例的 IP 地址注册到该目标组中，
      #      并根据任务的生命周期（启动、停止等）动态更新目标组中的 IP 地址。

      # Theres nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }
}

