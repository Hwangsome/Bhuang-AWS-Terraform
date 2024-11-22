#module "service_label" {
#  source = "./modules/ecs_alb_service_task_lable"
#  attributes = ["service"]
#
#  context = module.this.context
#}
#
### Security Groups
#resource "aws_security_group" "ecs_service" {
#  count       = local.enabled && var.network_mode == "awsvpc" ? 1 : 0
#  vpc_id      = module.vpc.vpc_id
#  name        = module.service_label.id
#  description = "Allow ALL egress from ECS service"
#  tags        = module.service_label.tags
#
#  lifecycle {
#    create_before_destroy = true
#  }
#}
#
