#resource "aws_lb_target_group" "green" {
#  name                 = var.green_target_group_label
#  port                 = var.target_group_port
#  protocol             = var.target_group_protocol
#  vpc_id               = module.vpc.vpc_id
#  target_type          = var.target_group_target_type
#  deregistration_delay = var.deregistration_delay
#
#  health_check {
#    protocol            = var.target_group_protocol
#    path                = var.health_check_path
#    port                = var.health_check_port
#    timeout             = var.health_check_timeout
#    healthy_threshold   = var.health_check_healthy_threshold
#    unhealthy_threshold = var.health_check_unhealthy_threshold
#    interval            = var.health_check_interval
#    matcher             = var.health_check_matcher
#  }
#
#  tags = local.green_target_group_label_tags
#}
#
#locals {
#  green_target_group_label_tags = {
#    tg_env_label = "green"
#  }
#}