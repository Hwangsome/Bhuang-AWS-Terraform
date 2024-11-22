locals {
  container_name = var.ecs_container_name
  container_port = var.ecs_container_port
  region         = "us-east-1"
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.11.4"
  cluster_name = "terraform-cluster"

  services = {
#    service configuration
    terraform-test-task-definition = {
#      deployment_circuit_breaker = {
#        enable = true
#        rollback = true
#      }
      deployment_controller = {
        type = "CODE_DEPLOY"
      }
      health_check_grace_period_seconds = 10

      load_balancer = {
        service = {
          target_group_arn = module.alb.target_groups["blue_env"].arn
          container_name   = local.container_name
          container_port   = local.container_port
        }
      }

      wait_for_steady_state = false

      assign_public_ip = true

#      subnet_ids = module.vpc.public_subnets
      subnet_ids = data.aws_subnets.default_vpc_public_subnets.ids

      # Service IAM role configuration
      iam_role_name = "ecs-service-role-create-by-terraform"

      container_definitions = {
        go-simple = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "058264261029.dkr.ecr.us-east-1.amazonaws.com/bhuang-devops/go-simplehttp-blue-green:6243bca1f0e327ace7f1b2e98d21f7387d993edc"
          name = local.container_name
#          health_check = {
#            command = ["CMD-SHELL", "curl -f http://localhost:${local.container_port}/health || exit 1"]
#          }

          port_mappings = [
            {
              name          = local.container_name
              containerPort = local.container_port
              hostPort      = local.container_port
              protocol      = "tcp"
            }
          ]

          # Example image used requires access to write to root filesystem
          readonly_root_filesystem = false


          enable_cloudwatch_logging = true
          memory_reservation = 100
          family = "terraform-test-task-definition"
        }
      }
      #          security group rule
      security_group_rules = {
        rule_1 = {
          type                   = "ingress"
          protocol               = "tcp"
          from_port              = 443
          to_port                = 443
          description            = "Allow HTTPS traffic"
          cidr_blocks            = ["0.0.0.0/0"]
        }

        #            allow blue
        rule_2 = {
          type                   = "ingress"
          protocol               = "tcp"
          from_port              = 80
          to_port                = 80
          description            = "Allow HTTP traffic"
          cidr_blocks            = ["0.0.0.0/0"]
        }
        #            allow green
        rule_3 = {
          type                   = "ingress"
          protocol               = "tcp"
          from_port              = 8080
          to_port                = 8080
          description            = "Allow HTTP traffic"
          cidr_blocks            = ["0.0.0.0/0"]
        }

        #            allow green
        rule_4 = {
          type                   = "egress"
          protocol               = "tcp"
          from_port              = 443
          to_port                = 443
          description            = "Allow HTTP traffic"
          cidr_blocks            = ["0.0.0.0/0"]
        }
      }
    }
  }

}

variable "ecs_container_port" {
    description = "The port the container listens on"
    type        = number
    default     = 80
}

variable "ecs_container_name" {
    description = "The name of the container"
    type        = string
    default     = "terraform-ecs-container"
}


output "task_definition_family" {
  description = "The unique name of the task definition"
  value       = module.ecs.service_as_json
}


