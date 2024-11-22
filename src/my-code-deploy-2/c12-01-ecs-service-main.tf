#
#
#resource "aws_ecs_service" "ignore_changes_task_definition" {
#  count                              = local.enabled && var.ignore_changes_task_definition ? 1 : 0
#  name                               = module.this.id
#  #  (Optional) Family and revision (family:revision) or full ARN of the task definition that you want to run in your service. Required unless using the EXTERNAL deployment controller. If a revision is not specified, the latest ACTIVE revision is used.
#  task_definition                    = coalesce(var.task_definition, "${join("", aws_ecs_task_definition.default.*.family)}:${join("", aws_ecs_task_definition.default.*.revision)}")
#  #  (Optional) Number of instances of the task definition to place and keep running. Defaults to 0. Do not specify if using the DAEMON scheduling strategy.
#  desired_count                      = var.desired_count
#  # (Optional) Upper limit (as a percentage of the service's desiredCount) of the number of running tasks that can be running in a service during a deployment. Not valid when using the DAEMON scheduling strategy.
#  deployment_maximum_percent         = var.deployment_maximum_percent
#  #  (Optional) Lower limit (as a percentage of the service's desiredCount) of the number of running tasks that must remain running and healthy in a service during a deployment.
#  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
#  #   (Optional) Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2147483647. Only valid for services configured to use load balancers
#  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
#  #  (Optional) Launch type on which to run your service. The valid values are EC2, FARGATE, and EXTERNAL. Defaults to EC2. Conflicts with capacity_provider_strategy.
#  launch_type                        = length(var.capacity_provider_strategies) > 0 ? null : var.launch_type
#  #  (Optional) Platform version on which to run your service. Only applicable for launch_type set to FARGATE. Defaults to LATEST. More information about Fargate platform versions can be found in the AWS ECS User Guide.
#  platform_version                   = var.launch_type == "FARGATE" ? var.platform_version : null
#  #  (Optional) Scheduling strategy to use for the service. The valid values are REPLICA and DAEMON. Defaults to REPLICA. Note that Tasks using the Fargate launch type or the CODE_DEPLOY or EXTERNAL deployment controller types don't support the DAEMON scheduling strategy.
#  scheduling_strategy                = var.launch_type == "FARGATE" ? "REPLICA" : var.scheduling_strategy
#  #  (Optional) Whether to enable Amazon ECS managed tags for the tasks within the service.
#  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
#  #  (Optional) ARN of the IAM role that allows Amazon ECS to make calls to your load balancer on your behalf. This parameter is required if you are using a load balancer with your service, but only if your task definition does not use the awsvpc network mode. If using awsvpc network mode, do not specify this role. If your account has already created the Amazon ECS service-linked role, that role is used by default for your service unless you specify a role here.
##  iam_role                           = local.enable_ecs_service_role ? coalesce(var.service_role_arn, join("", aws_iam_role.ecs_service.*.arn)) : null
#  #  (Optional) If true, Terraform will wait for the service to reach a steady state (like aws ecs wait services-stable) before continuing. Default false.
#  wait_for_steady_state              = var.wait_for_steady_state
#
##  (Optional) Capacity provider strategies to use for the service. Can be one or more. These can be updated without destroying and recreating the service only if force_new_deployment = true and not changing from 0 capacity_provider_strategy blocks to greater than 0, or vice versa. See below. Conflicts with launch_type.
#  dynamic "capacity_provider_strategy" {
#    for_each = var.capacity_provider_strategies
#    content {
##      (Required) Short name of the capacity provider.
#      capacity_provider = capacity_provider_strategy.value.capacity_provider
##      (Required) Relative percentage of the total number of launched tasks that should use the specified capacity provider.
#      weight            = capacity_provider_strategy.value.weight
##      (Optional) Number of tasks, at a minimum, to run on the specified capacity provider. Only one capacity provider in a capacity provider strategy can have a base defined.
#      base              = lookup(capacity_provider_strategy.value, "base", null)
#    }
#  }
#
#  dynamic "service_registries" {
#    for_each = var.service_registries
#    content {
#      registry_arn   = service_registries.value.registry_arn
#      port           = lookup(service_registries.value, "port", null)
#      container_name = lookup(service_registries.value, "container_name", null)
#      container_port = lookup(service_registries.value, "container_port", null)
#    }
#  }
#
#  dynamic "ordered_placement_strategy" {
#    for_each = var.ordered_placement_strategy
#    content {
#      type  = ordered_placement_strategy.value.type
#      field = lookup(ordered_placement_strategy.value, "field", null)
#    }
#  }
#
#  dynamic "placement_constraints" {
#    for_each = var.service_placement_constraints
#    content {
#      type       = placement_constraints.value.type
#      expression = lookup(placement_constraints.value, "expression", null)
#    }
#  }
#
#  dynamic "load_balancer" {
#    for_each = var.ecs_load_balancers
#    content {
#      container_name   = load_balancer.value.container_name
#      container_port   = load_balancer.value.container_port
#      elb_name         = lookup(load_balancer.value, "elb_name", null)
#      target_group_arn = lookup(load_balancer.value, "target_group_arn", null)
#    }
#  }
#
#  cluster        = aws_ecs_cluster.default.arn
#  propagate_tags = var.propagate_tags
#  tags           = var.use_old_arn ? null : module.this.tags
#
##  (Optional) Configuration block for deployment controller configuration
#  deployment_controller {
##    (Optional) Type of deployment controller. Valid values: CODE_DEPLOY, ECS, EXTERNAL. Default: ECS.
#    type = var.deployment_controller_type
#  }
#
#  # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#network_configuration
#  dynamic "network_configuration" {
#    for_each = var.network_mode == "awsvpc" ? ["true"] : []
#    content {
##      (Optional) Security groups associated with the task or service. If you do not specify a security group, the default security group for the VPC is used.
#      security_groups  = compact(concat(var.security_group_ids, aws_security_group.ecs_service.*.id))
##       (Required) Subnets associated with the task or service.
#      subnets          = module.vpc.public_subnets
##      (Optional) Assign a public IP address to the ENI (Fargate launch type only). Valid values are true or false. Default false.
#      assign_public_ip = var.assign_public_ip
#    }
#  }
#
#  lifecycle {
#    ignore_changes = [task_definition]
#  }
#}