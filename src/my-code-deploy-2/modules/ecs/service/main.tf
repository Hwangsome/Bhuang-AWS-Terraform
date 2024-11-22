data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
}

################################################################################
# Service
################################################################################

locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-external.html
  is_external_deployment = try(var.deployment_controller.type, null) == "EXTERNAL"
  is_daemon              = var.scheduling_strategy == "DAEMON"
  is_fargate             = var.launch_type == "FARGATE"

  # Flattened `network_configuration`
  network_configuration = {
    assign_public_ip = var.assign_public_ip
    security_groups  = flatten(concat([try(aws_security_group.this[0].id, [])], var.security_group_ids))
    subnets          = var.subnet_ids
  }

  create_service = var.create && var.create_service
}

resource "aws_ecs_service" "this" {
  count = local.create_service && !var.ignore_task_definition_changes ? 1 : 0

#  参数 alarms，用于在 ECS 服务的蓝/绿部署中集成 CloudWatch 警报。该参数在 蓝/绿部署（Blue/Green Deployment） 配置中尤为重要，因为它允许您设置部署的健康状况监控。
#  通过配置 alarms 参数，您可以在部署过程中设置一组 CloudWatch 警报，这些警报用于检测 ECS 服务的关键指标是否处于预期范围内。如果这些警报触发，部署会自动失败，并且可以回滚到之前的稳定版本，以确保部署的可靠性和服务的可用性。
  dynamic "alarms" {
    for_each = length(var.alarms) > 0 ? [var.alarms] : []

    content {
#      alarm_names：一个字符串列表，包含了希望监控的 CloudWatch 警报名称。部署会监控这些警报，当这些警报触发时，部署会被标记为失败。
      alarm_names = alarms.value.alarm_names
#      布尔值，用于启用或禁用警报监控功能。如果设置为 false，即使 alarm_names 中的警报触发，部署也不会失败。默认值为 true。
      enable      = try(alarms.value.enable, true)
#      布尔值，用于配置在警报触发时是否自动回滚。如果设置为 true，当 alarm_names 中的任何警报触发时，ECS 会自动回滚到上一个稳定版本。默认值为 true
      rollback    = try(alarms.value.rollback, true)
    }
  }

  dynamic "capacity_provider_strategy" {
    # Set by task set if deployment controller is external
    for_each = { for k, v in var.capacity_provider_strategy : k => v if !local.is_external_deployment }

    content {
      base              = try(capacity_provider_strategy.value.base, null)
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = try(capacity_provider_strategy.value.weight, null)
    }
  }

  cluster = var.cluster_arn

#  在 AWS ECS 中，deployment_circuit_breaker 是 ECS 服务的一个选项，用于配置 部署熔断器。这个功能帮助在 ECS 服务的部署过程中监控部署是否成功，并在检测到失败时自动回滚部署，以防止不稳定或错误的版本影响生产环境。该功能特别适用于需要高可用性和快速恢复的应用。
#  deployment_circuit_breaker 的主要功能
#   自动检测部署失败：如果 ECS 在部署过程中检测到服务的部署失败，熔断器会触发回滚。
#   自动回滚：当部署失败时，ECS 会自动将服务回滚到上一个稳定版本，而无需手动干预。
#   减少停机时间：该功能可以帮助减少服务因部署失败而导致的停机时间，从而保证应用的高可用性。
# 在 Terraform 的 aws_ecs_service 资源中，deployment_circuit_breaker 是一个配置块，包含两个参数：
# enabled：布尔值，指示是否启用部署熔断器。设为 true 以启用该功能。
#rollback：布尔值，指示在检测到失败时是否自动回滚到上一个稳定版本。设为 true 以启用自动回滚。
  dynamic "deployment_circuit_breaker" {
    for_each = length(var.deployment_circuit_breaker) > 0 ? [var.deployment_circuit_breaker] : []

    content {
#      enabled = true：启用部署熔断器。ECS 会在部署过程中监控服务的健康状态，检测是否有任务启动失败或健康检查未通过的情况。
      enable   = deployment_circuit_breaker.value.enable
#      rollback = true：如果部署失败，自动回滚到上一个稳定版本。这样可以快速恢复服务，减少停机时间。
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

# deployment_controller 是 ECS 服务的一个参数，用于定义 ECS 服务的部署控制器类型，即指定如何管理和控制服务的部署过程。
#  通过 deployment_controller，您可以选择使用 ECS 内置的部署控制器，或将 ECS 与 AWS CodeDeploy 集成，使用 CodeDeploy 的蓝/绿部署功能。

#  deployment_controller 有三个主要选项，分别适用于不同的部署需求：
#   ECS（默认）：使用 ECS 内置的部署控制器进行 滚动更新（Rolling Update）。这是 ECS 的默认部署方式，适合大多数简单的应用部署场景。
#   CODE_DEPLOY：使用 AWS CodeDeploy 控制部署过程，支持 蓝/绿部署（Blue/Green Deployment）。这种方式更适合需要无停机部署、流量控制和逐步切换流量的应用。
#   EXTERNAL：允许使用外部部署控制器，通常适用于使用 Kubernetes 或其他自定义控制器的场景。此模式主要用于 Amazon ECS 的 AWS Fargate 上的 Amazon EKS 集成，不适用于常规的 ECS 任务。

#  在创建或更新服务时，在 部署类型 (Deployment type) 部分，您会看到两种部署选项：
#   Rolling update（滚动更新）：这是 ECS 的默认部署方式，控制器类型为 ECS。
#   Blue/green（蓝/绿部署）：这是通过 AWS CodeDeploy 管理的蓝/绿部署方式，控制器类型为 CODE_DEPLOY。
# 如果您选择 Rolling update（滚动更新），系统将默认使用 ECS 作为 deployment_controller。
# 如果您选择 Blue/green（蓝/绿部署），则会使用 CODE_DEPLOY 作为 deployment_controller，并需要进一步配置 CodeDeploy 的蓝/绿部署选项（例如负载均衡和流量控制）。
# (Optional) Type of deployment controller. Valid values: CODE_DEPLOY, ECS, EXTERNAL. Default: ECS
dynamic "deployment_controller" {
    for_each = length(var.deployment_controller) > 0 ? [var.deployment_controller] : []

    content {
      type = try(deployment_controller.value.type, null)
    }
  }

  deployment_maximum_percent         = local.is_daemon || local.is_external_deployment ? null : var.deployment_maximum_percent
  deployment_minimum_healthy_percent = local.is_daemon || local.is_external_deployment ? null : var.deployment_minimum_healthy_percent
  desired_count                      = local.is_daemon || local.is_external_deployment ? null : var.desired_count
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  enable_execute_command             = var.enable_execute_command
  force_new_deployment               = local.is_external_deployment ? null : var.force_new_deployment
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  iam_role                           = local.iam_role_arn
  launch_type                        = local.is_external_deployment || length(var.capacity_provider_strategy) > 0 ? null : var.launch_type

#  在 aws_ecs_service 资源中，load_balancer 参数用于配置 ECS 服务的 负载均衡。它定义了 ECS 服务和负载均衡器之间的关系，指定了 ECS 服务的容器如何接收外部流量。
#  load_balancer 参数用于将 ECS 服务与 Elastic Load Balancer (ELB) 集成，通常是 Application Load Balancer (ALB) 或 Network Load Balancer (NLB)。通过配置负载均衡器，您可以将流量分配到 ECS 服务的任务中，从而实现高可用性和自动扩展。
#  在 ECS 服务中，load_balancer 允许您指定多个属性，例如目标组 ARN、容器名称和端口，以便正确地将流量引导到服务的容器。
  dynamic "load_balancer" {
    # Set by task set if deployment controller is external
    for_each = { for k, v in var.load_balancer : k => v if !local.is_external_deployment }

    content {
#      container_name（必填）：指定服务任务中的容器名称，流量会被路由到该容器
      container_name   = load_balancer.value.container_name
#      container_port（必填）：指定容器接收流量的端口号。负载均衡器会将流量路由到该端口。
      container_port   = load_balancer.value.container_port
#      (Required for ELB Classic) Name of the ELB (Classic) to associate with the service.
      elb_name         = try(load_balancer.value.elb_name, null)
#      target_group_arn（必填）：指定负载均衡器目标组的 ARN。负载均衡器将根据该目标组的配置将流量路由到 ECS 服务的任务容器。
      target_group_arn = try(load_balancer.value.target_group_arn, null)
    }
  }

  name = var.name

  dynamic "network_configuration" {
    # Set by task set if deployment controller is external
    for_each = var.network_mode == "awsvpc" && !local.is_external_deployment ? [local.network_configuration] : []

    content {
      assign_public_ip = network_configuration.value.assign_public_ip
      security_groups  = network_configuration.value.security_groups
      subnets          = network_configuration.value.subnets
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = var.ordered_placement_strategy

    content {
      field = try(ordered_placement_strategy.value.field, null)
      type  = ordered_placement_strategy.value.type
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints

    content {
      expression = try(placement_constraints.value.expression, null)
      type       = placement_constraints.value.type
    }
  }

  # Set by task set if deployment controller is external
  platform_version    = local.is_fargate && !local.is_external_deployment ? var.platform_version : null
  scheduling_strategy = local.is_fargate ? "REPLICA" : var.scheduling_strategy

  dynamic "service_connect_configuration" {
    for_each = length(var.service_connect_configuration) > 0 ? [var.service_connect_configuration] : []

    content {
      enabled = try(service_connect_configuration.value.enabled, true)

      dynamic "log_configuration" {
        for_each = try([service_connect_configuration.value.log_configuration], [])

        content {
          log_driver = try(log_configuration.value.log_driver, null)
          options    = try(log_configuration.value.options, null)

          dynamic "secret_option" {
            for_each = try(log_configuration.value.secret_option, [])

            content {
              name       = secret_option.value.name
              value_from = secret_option.value.value_from
            }
          }
        }
      }

      namespace = lookup(service_connect_configuration.value, "namespace", null)

      dynamic "service" {
        for_each = try([service_connect_configuration.value.service], [])

        content {

          dynamic "client_alias" {
            for_each = try([service.value.client_alias], [])

            content {
              dns_name = try(client_alias.value.dns_name, null)
              port     = client_alias.value.port
            }
          }

          discovery_name        = try(service.value.discovery_name, null)
          ingress_port_override = try(service.value.ingress_port_override, null)
          port_name             = service.value.port_name
        }
      }
    }
  }

  dynamic "service_registries" {
    # Set by task set if deployment controller is external
    for_each = length(var.service_registries) > 0 ? [{ for k, v in var.service_registries : k => v if !local.is_external_deployment }] : []

    content {
      container_name = try(service_registries.value.container_name, null)
      container_port = try(service_registries.value.container_port, null)
      port           = try(service_registries.value.port, null)
      registry_arn   = service_registries.value.registry_arn
    }
  }

  task_definition       = local.task_definition
  triggers              = var.triggers
#  If true, Terraform will wait for the service to reach a steady state (like aws ecs wait services-stable) before continuing. Default false.
#  true：Terraform 会等待服务达到稳定状态（即所有任务都已启动并处于运行状态）。
#  false：Terraform 不会等待服务达到稳定状态，而是立即继续执行后续操作。（默认值）
  wait_for_steady_state = var.wait_for_steady_state

  propagate_tags = var.propagate_tags
  tags           = merge(var.tags, var.service_tags)

  timeouts {
    create = try(var.timeouts.create, null)
    update = try(var.timeouts.update, null)
    delete = try(var.timeouts.delete, null)
  }

  depends_on = [
    aws_iam_role_policy_attachment.service
  ]

  lifecycle {
    ignore_changes = [
      desired_count, # Always ignored
    ]
  }
}

################################################################################
# Service - Ignore `task_definition`
################################################################################

resource "aws_ecs_service" "ignore_task_definition" {
  count = local.create_service && var.ignore_task_definition_changes ? 1 : 0

  dynamic "alarms" {
    for_each = length(var.alarms) > 0 ? [var.alarms] : []

    content {
      alarm_names = alarms.value.alarm_names
      enable      = try(alarms.value.enable, true)
      rollback    = try(alarms.value.rollback, true)
    }
  }

  dynamic "capacity_provider_strategy" {
    # Set by task set if deployment controller is external
    for_each = { for k, v in var.capacity_provider_strategy : k => v if !local.is_external_deployment }

    content {
      base              = try(capacity_provider_strategy.value.base, null)
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = try(capacity_provider_strategy.value.weight, null)
    }
  }

  cluster = var.cluster_arn

  dynamic "deployment_circuit_breaker" {
    for_each = length(var.deployment_circuit_breaker) > 0 ? [var.deployment_circuit_breaker] : []

    content {
      enable   = deployment_circuit_breaker.value.enable
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

  dynamic "deployment_controller" {
    for_each = length(var.deployment_controller) > 0 ? [var.deployment_controller] : []

    content {
      type = try(deployment_controller.value.type, null)
    }
  }

  deployment_maximum_percent         = local.is_daemon || local.is_external_deployment ? null : var.deployment_maximum_percent
  deployment_minimum_healthy_percent = local.is_daemon || local.is_external_deployment ? null : var.deployment_minimum_healthy_percent
  desired_count                      = local.is_daemon || local.is_external_deployment ? null : var.desired_count
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  enable_execute_command             = var.enable_execute_command
  force_new_deployment               = local.is_external_deployment ? null : var.force_new_deployment
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  iam_role                           = local.iam_role_arn
  launch_type                        = local.is_external_deployment || length(var.capacity_provider_strategy) > 0 ? null : var.launch_type

  dynamic "load_balancer" {
    # Set by task set if deployment controller is external
    for_each = { for k, v in var.load_balancer : k => v if !local.is_external_deployment }

    content {
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
      elb_name         = try(load_balancer.value.elb_name, null)
      target_group_arn = try(load_balancer.value.target_group_arn, null)
    }
  }

  name = var.name

  dynamic "network_configuration" {
    # Set by task set if deployment controller is external
    for_each = var.network_mode == "awsvpc" ? [{ for k, v in local.network_configuration : k => v if !local.is_external_deployment }] : []

    content {
      assign_public_ip = network_configuration.value.assign_public_ip
      security_groups  = network_configuration.value.security_groups
      subnets          = network_configuration.value.subnets
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = var.ordered_placement_strategy

    content {
      field = try(ordered_placement_strategy.value.field, null)
      type  = ordered_placement_strategy.value.type
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints

    content {
      expression = try(placement_constraints.value.expression, null)
      type       = placement_constraints.value.type
    }
  }

  # Set by task set if deployment controller is external
  platform_version    = local.is_fargate && !local.is_external_deployment ? var.platform_version : null
  scheduling_strategy = local.is_fargate ? "REPLICA" : var.scheduling_strategy

  dynamic "service_connect_configuration" {
    for_each = length(var.service_connect_configuration) > 0 ? [var.service_connect_configuration] : []

    content {
      enabled = try(service_connect_configuration.value.enabled, true)

      dynamic "log_configuration" {
        for_each = try([service_connect_configuration.value.log_configuration], [])

        content {
          log_driver = try(log_configuration.value.log_driver, null)
          options    = try(log_configuration.value.options, null)

          dynamic "secret_option" {
            for_each = try(log_configuration.value.secret_option, [])

            content {
              name       = secret_option.value.name
              value_from = secret_option.value.value_from
            }
          }
        }
      }

      namespace = lookup(service_connect_configuration.value, "namespace", null)

      dynamic "service" {
        for_each = try([service_connect_configuration.value.service], [])

        content {

          dynamic "client_alias" {
            for_each = try([service.value.client_alias], [])

            content {
              dns_name = try(client_alias.value.dns_name, null)
              port     = client_alias.value.port
            }
          }

          discovery_name        = try(service.value.discovery_name, null)
          ingress_port_override = try(service.value.ingress_port_override, null)
          port_name             = service.value.port_name
        }
      }
    }
  }

  dynamic "service_registries" {
    # Set by task set if deployment controller is external
    for_each = length(var.service_registries) > 0 ? [{ for k, v in var.service_registries : k => v if !local.is_external_deployment }] : []

    content {
      container_name = try(service_registries.value.container_name, null)
      container_port = try(service_registries.value.container_port, null)
      port           = try(service_registries.value.port, null)
      registry_arn   = service_registries.value.registry_arn
    }
  }

  task_definition       = local.task_definition
  triggers              = var.triggers
  wait_for_steady_state = var.wait_for_steady_state

  propagate_tags = var.propagate_tags
  tags           = var.tags

  timeouts {
    create = try(var.timeouts.create, null)
    update = try(var.timeouts.update, null)
    delete = try(var.timeouts.delete, null)
  }

  depends_on = [
    aws_iam_role_policy_attachment.service
  ]

  lifecycle {
    ignore_changes = [
      desired_count, # Always ignored
#      忽略 task_definition 的更改。意味着即使任务定义发生更改，Terraform 也不会对服务进行重新部署。
      task_definition,
      load_balancer,
    ]
  }
}

################################################################################
# Service - IAM Role
################################################################################

locals {
  # Role is not required if task definition uses `awsvpc` network mode or if a load balancer is not used
  needs_iam_role  = var.network_mode != "awsvpc" && length(var.load_balancer) > 0
  create_iam_role = var.create && var.create_iam_role && local.needs_iam_role
  iam_role_arn    = local.needs_iam_role ? try(aws_iam_role.service[0].arn, var.iam_role_arn) : null

  iam_role_name = try(coalesce(var.iam_role_name, var.name), "")
}

data "aws_iam_policy_document" "service_assume" {
  count = local.create_iam_role ? 1 : 0

  statement {
    sid     = "ECSServiceAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service" {
  count = local.create_iam_role ? 1 : 0

  name        = var.iam_role_use_name_prefix ? null : local.iam_role_name
  name_prefix = var.iam_role_use_name_prefix ? "${local.iam_role_name}-" : null
  path        = var.iam_role_path
  description = var.iam_role_description

  assume_role_policy    = data.aws_iam_policy_document.service_assume[0].json
  permissions_boundary  = var.iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

data "aws_iam_policy_document" "service" {
  count = local.create_iam_role ? 1 : 0

  statement {
    sid       = "ECSService"
    resources = ["*"]

    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets"
    ]
  }

  dynamic "statement" {
    for_each = var.iam_role_statements

    content {
      sid           = try(statement.value.sid, null)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, null)
      not_resources = try(statement.value.not_resources, null)

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}

resource "aws_iam_policy" "service" {
  count = local.create_iam_role ? 1 : 0

  name        = var.iam_role_use_name_prefix ? null : local.iam_role_name
  name_prefix = var.iam_role_use_name_prefix ? "${local.iam_role_name}-" : null
  description = coalesce(var.iam_role_description, "ECS service policy that allows Amazon ECS to make calls to your load balancer on your behalf")
  policy      = data.aws_iam_policy_document.service[0].json

  tags = merge(var.tags, var.iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "service" {
  count = local.create_iam_role ? 1 : 0

  role       = aws_iam_role.service[0].name
  policy_arn = aws_iam_policy.service[0].arn
}

################################################################################
# Container Definition
################################################################################

module "container_definition" {
  source = "../container_definition"

  for_each = { for k, v in var.container_definitions : k => v if local.create_task_definition && try(v.create, true) }

  operating_system_family = try(var.runtime_platform.operating_system_family, "LINUX")

  # Container Definition
  command                  = try(each.value.command, var.container_definition_defaults.command, [])
  cpu                      = try(each.value.cpu, var.container_definition_defaults.cpu, null)
  dependencies             = try(each.value.dependencies, var.container_definition_defaults.dependencies, []) # depends_on is a reserved word
  disable_networking       = try(each.value.disable_networking, var.container_definition_defaults.disable_networking, null)
  dns_search_domains       = try(each.value.dns_search_domains, var.container_definition_defaults.dns_search_domains, [])
  dns_servers              = try(each.value.dns_servers, var.container_definition_defaults.dns_servers, [])
  docker_labels            = try(each.value.docker_labels, var.container_definition_defaults.docker_labels, {})
  docker_security_options  = try(each.value.docker_security_options, var.container_definition_defaults.docker_security_options, [])
  enable_execute_command   = try(each.value.enable_execute_command, var.container_definition_defaults.enable_execute_command, var.enable_execute_command)
  entrypoint               = try(each.value.entrypoint, var.container_definition_defaults.entrypoint, [])
  environment              = try(each.value.environment, var.container_definition_defaults.environment, [])
  environment_files        = try(each.value.environment_files, var.container_definition_defaults.environment_files, [])
  essential                = try(each.value.essential, var.container_definition_defaults.essential, null)
  extra_hosts              = try(each.value.extra_hosts, var.container_definition_defaults.extra_hosts, [])
  firelens_configuration   = try(each.value.firelens_configuration, var.container_definition_defaults.firelens_configuration, {})
  health_check             = try(each.value.health_check, var.container_definition_defaults.health_check, {})
  hostname                 = try(each.value.hostname, var.container_definition_defaults.hostname, null)
  image                    = try(each.value.image, var.container_definition_defaults.image, null)
  interactive              = try(each.value.interactive, var.container_definition_defaults.interactive, false)
  links                    = try(each.value.links, var.container_definition_defaults.links, [])
  linux_parameters         = try(each.value.linux_parameters, var.container_definition_defaults.linux_parameters, {})
  log_configuration        = try(each.value.log_configuration, var.container_definition_defaults.log_configuration, {})
  memory                   = try(each.value.memory, var.container_definition_defaults.memory, null)
  memory_reservation       = try(each.value.memory_reservation, var.container_definition_defaults.memory_reservation, null)
  mount_points             = try(each.value.mount_points, var.container_definition_defaults.mount_points, [])
  name                     = try(each.value.name, each.key)
  port_mappings            = try(each.value.port_mappings, var.container_definition_defaults.port_mappings, [])
  privileged               = try(each.value.privileged, var.container_definition_defaults.privileged, false)
  pseudo_terminal          = try(each.value.pseudo_terminal, var.container_definition_defaults.pseudo_terminal, false)
  readonly_root_filesystem = try(each.value.readonly_root_filesystem, var.container_definition_defaults.readonly_root_filesystem, true)
  repository_credentials   = try(each.value.repository_credentials, var.container_definition_defaults.repository_credentials, {})
  resource_requirements    = try(each.value.resource_requirements, var.container_definition_defaults.resource_requirements, [])
  secrets                  = try(each.value.secrets, var.container_definition_defaults.secrets, [])
  start_timeout            = try(each.value.start_timeout, var.container_definition_defaults.start_timeout, 30)
  stop_timeout             = try(each.value.stop_timeout, var.container_definition_defaults.stop_timeout, 120)
  system_controls          = try(each.value.system_controls, var.container_definition_defaults.system_controls, [])
  ulimits                  = try(each.value.ulimits, var.container_definition_defaults.ulimits, [])
  user                     = try(each.value.user, var.container_definition_defaults.user, 0)
  volumes_from             = try(each.value.volumes_from, var.container_definition_defaults.volumes_from, [])
  working_directory        = try(each.value.working_directory, var.container_definition_defaults.working_directory, null)

  # CloudWatch Log Group
  service                                = var.name
  enable_cloudwatch_logging              = try(each.value.enable_cloudwatch_logging, var.container_definition_defaults.enable_cloudwatch_logging, true)
  create_cloudwatch_log_group            = try(each.value.create_cloudwatch_log_group, var.container_definition_defaults.create_cloudwatch_log_group, true)
  cloudwatch_log_group_name              = try(each.value.cloudwatch_log_group_name, var.container_definition_defaults.cloudwatch_log_group_name, null)
  cloudwatch_log_group_use_name_prefix   = try(each.value.cloudwatch_log_group_use_name_prefix, var.container_definition_defaults.cloudwatch_log_group_use_name_prefix, false)
  cloudwatch_log_group_retention_in_days = try(each.value.cloudwatch_log_group_retention_in_days, var.container_definition_defaults.cloudwatch_log_group_retention_in_days, 14)
  cloudwatch_log_group_kms_key_id        = try(each.value.cloudwatch_log_group_kms_key_id, var.container_definition_defaults.cloudwatch_log_group_kms_key_id, null)

  tags = var.tags
}

################################################################################
# Task Definition
################################################################################

locals {
  create_task_definition = var.create && var.create_task_definition

  # This allows us to query both the existing as well as Terraform's state and get
  # and get the max version of either source, useful for when external resources
  # update the container definition
  max_task_def_revision = local.create_task_definition ? max(aws_ecs_task_definition.this[0].revision, data.aws_ecs_task_definition.this[0].revision) : 0
  task_definition       = local.create_task_definition ? "${aws_ecs_task_definition.this[0].family}:${local.max_task_def_revision}" : var.task_definition_arn
}

# This allows us to query both the existing as well as Terraform's state and get
# and get the max version of either source, useful for when external resources
# update the container definition
data "aws_ecs_task_definition" "this" {
  count = local.create_task_definition ? 1 : 0

  task_definition = aws_ecs_task_definition.this[0].family

  depends_on = [
    # Needs to exist first on first deployment
    aws_ecs_task_definition.this
  ]
}

resource "aws_ecs_task_definition" "this" {
  count = local.create_task_definition ? 1 : 0

  # Convert map of maps to array of maps before JSON encoding
  container_definitions = jsonencode([for k, v in module.container_definition : v.container_definition])
#  容器级别的资源分配限制与任务级别的资源分配值是不同的。任务级资源定义了整个任务（可能包含多个容器）的总资源限制，而容器级别的资源限制定义了每个容器可以使用的资源。
  cpu                   = var.cpu

# 在 AWS Fargate 上运行的任务默认会分配至少 20 GiB 的临时存储（ephemeral storage）。临时存储是任务在运行期间使用的本地存储空间，用于存放在任务执行中产生的临时文件、缓存等数据。这个存储空间在任务结束后会被销毁，不会被持久保存。
#  临时存储仅在任务运行时有效：当任务结束或被终止时，临时存储中的数据将被销毁。它不适合用来存储持久性数据。
  dynamic "ephemeral_storage" {
    for_each = length(var.ephemeral_storage) > 0 ? [var.ephemeral_storage] : []

    content {
      size_in_gib = ephemeral_storage.value.size_in_gib
    }
  }

#  在 AWS ECS 中，任务执行角色（Task Execution Role） 是一个 IAM 角色，用于允许 ECS 容器代理（Container Agent）代表您调用 AWS API。这些 API 调用通常涉及 ECS 任务在运行过程中所需的权限，例如拉取 ECR 镜像、存储日志到 CloudWatch 等。
#  任务执行角色 vs 任务角色
#  任务执行角色（Task Execution Role）：用于 ECS 容器代理在任务执行期间访问 AWS 服务的权限，例如拉取 ECR 镜像、存储日志到 CloudWatch。
#  任务角色（Task Role）：用于容器内的应用程序访问 AWS 服务的权限。比如，如果容器内的应用程序需要访问 S3 或 DynamoDB，您应该配置任务角色，而不是任务执行角色。
  execution_role_arn = try(aws_iam_role.task_exec[0].arn, var.task_exec_iam_role_arn)
#  任务定义的名字， 你必须输入 family 或者 name
  family             = coalesce(var.family, var.name)

#  通常不需要！
  dynamic "inference_accelerator" {
    for_each = var.inference_accelerator

    content {
#      (Required) Elastic Inference accelerator device name. The deviceName must also be referenced in a container definition as a ResourceRequirement.
#      device_name：指定加速器的设备名称。容器可以使用这个设备名称来访问硬件加速器。
      device_name = inference_accelerator.value.device_name
#      (Required) Elastic Inference accelerator type to use.
#      device_type：指定加速器的类型，比如 NVIDIA GPU 或 AWS Inferentia 芯片（如 eia2.medium 等）。
      device_type = inference_accelerator.value.device_type
    }
  }

#  (Optional) IPC resource namespace to be used for the containers in the task The valid values are host, task, and none
#  Fargate 不支持 ipc_mode 设置：目前 AWS Fargate 不支持自定义 ipc_mode，即默认使用 none。
  ipc_mode     = var.ipc_mode
#  Amount (in MiB) of memory used by the task. If the `requires_compatibilities` is `FARGATE` this field is required
  memory       = var.memory
#  Docker networking mode to use for the containers in the task. Valid values are `none`, `bridge`, `awsvpc`, and `host`"
  network_mode = var.network_mode
#  Process namespace to use for the containers in the task. The valid values are `host` and `task`"
#  pid_mode 是用于控制容器的 进程 ID（PID）命名空间 的参数。该参数决定了容器是否与主机或同一任务中的其他容器共享 PID 命名空间。通过设置 pid_mode，您可以控制容器与主机或其他容器之间的进程隔离程度。
#  pid_mode 仅在 Linux 容器 中支持，不适用于 Windows 容器。
#  AWS Fargate 不支持 pid_mode 配置，因此该选项仅适用于基于 EC2 的 ECS 集群
#  task：

#在 task 模式下，同一任务中的所有容器将共享 PID 命名空间。
#这意味着在同一个 ECS 任务中的容器可以互相查看彼此的进程，并且可以通过 ps 等命令看到同一任务中其他容器的进程。
#适用于需要在容器之间进行进程管理的应用，例如需要在一个容器中监控和管理其他容器进程的情况。
#host：
#
#在 host 模式下，容器与主机实例共享 PID 命名空间。
#这意味着容器可以访问和查看主机上的所有进程，并且主机上的所有进程也可以被容器看到。
#适用于需要直接访问主机进程的应用场景，但需要谨慎使用，因为它会降低安全性。
#不设置（默认值）：
#
#如果未设置 pid_mode，每个容器将使用其自己的 PID 命名空间，与其他容器和主机系统隔离。
#这是默认模式，最安全，因为它不会在任务中的容器、主机或其他任务之间共享 PID。
  pid_mode     = var.pid_mode

#  placement_constraints 不支持fargate
  dynamic "placement_constraints" {
    for_each = var.task_definition_placement_constraints

    content {
      expression = try(placement_constraints.value.expression, null)
      type       = placement_constraints.value.type
    }
  }

  dynamic "proxy_configuration" {
    for_each = length(var.proxy_configuration) > 0 ? [var.proxy_configuration] : []

    content {
      container_name = proxy_configuration.value.container_name
      properties     = try(proxy_configuration.value.properties, null)
      type           = try(proxy_configuration.value.type, null)
    }
  }

#  Set of launch types required by the task. The valid values are `EC2` and `FARGATE`
  requires_compatibilities = var.requires_compatibilities

#  default = {
#  operating_system_family = "LINUX"
#  cpu_architecture        = "X86_64"
#}
  dynamic "runtime_platform" {
    for_each = length(var.runtime_platform) > 0 ? [var.runtime_platform] : []

    content {
      cpu_architecture        = try(runtime_platform.value.cpu_architecture, null)
      operating_system_family = try(runtime_platform.value.operating_system_family, null)
    }
  }

#  If true, the task is not deleted when the service is deleted
  skip_destroy  = var.skip_destroy

#  ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services.
#  任务角色（Task Role）：用于容器内的应用程序访问 AWS 服务的权限。比如，如果容器内的应用程序需要访问 S3 或 DynamoDB，您应该配置任务角色，而不是任务执行角色。
  task_role_arn = try(aws_iam_role.tasks[0].arn, var.tasks_iam_role_arn)

#  volume的配置
  dynamic "volume" {
    for_each = var.volume

    content {
      dynamic "docker_volume_configuration" {
        for_each = try([volume.value.docker_volume_configuration], [])

        content {
          autoprovision = try(docker_volume_configuration.value.autoprovision, null)
          driver        = try(docker_volume_configuration.value.driver, null)
          driver_opts   = try(docker_volume_configuration.value.driver_opts, null)
          labels        = try(docker_volume_configuration.value.labels, null)
          scope         = try(docker_volume_configuration.value.scope, null)
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = try([volume.value.efs_volume_configuration], [])

        content {
          dynamic "authorization_config" {
            for_each = try([efs_volume_configuration.value.authorization_config], [])

            content {
              access_point_id = try(authorization_config.value.access_point_id, null)
              iam             = try(authorization_config.value.iam, null)
            }
          }

          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = try(efs_volume_configuration.value.root_directory, null)
          transit_encryption      = try(efs_volume_configuration.value.transit_encryption, null)
          transit_encryption_port = try(efs_volume_configuration.value.transit_encryption_port, null)
        }
      }

      dynamic "fsx_windows_file_server_volume_configuration" {
        for_each = try([volume.value.fsx_windows_file_server_volume_configuration], [])

        content {
          dynamic "authorization_config" {
            for_each = try([fsx_windows_file_server_volume_configuration.value.authorization_config], [])

            content {
              credentials_parameter = authorization_config.value.credentials_parameter
              domain                = authorization_config.value.domain
            }
          }

          file_system_id = fsx_windows_file_server_volume_configuration.value.file_system_id
          root_directory = fsx_windows_file_server_volume_configuration.value.root_directory
        }
      }

      host_path = try(volume.value.host_path, null)
      name      = try(volume.value.name, volume.key)
    }
  }

  tags = merge(var.tags, var.task_tags)

  depends_on = [
    aws_iam_role_policy_attachment.tasks,
    aws_iam_role_policy_attachment.task_exec,
    aws_iam_role_policy_attachment.task_exec_additional,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Task Execution - IAM Role  定义Task Agent 的IAM Role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
################################################################################

locals {
  task_exec_iam_role_name = try(coalesce(var.task_exec_iam_role_name, var.name), "")

  create_task_exec_iam_role =  var.create_task_exec_iam_role
  create_task_exec_policy   = local.create_task_exec_iam_role && var.create_task_exec_policy
}

data "aws_iam_policy_document" "task_exec_assume" {
  count = local.create_task_exec_iam_role ? 1 : 0

  statement {
    sid     = "ECSTaskExecutionAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# aws_iam_role 是一个用于创建 IAM 角色的 Terraform 资源。
#IAM 角色是一种 AWS 身份，用于允许 AWS 服务或账户访问资源，而不需要使用用户凭证。
#它具有特定的权限策略，并且只能被指定的实体（如 AWS 服务、账户或 IAM 用户）“假设”或使用。
# 这里表示 的是 ecs-tasks 服务可以假设这个角色， 执行这个role中定义的权限
resource "aws_iam_role" "task_exec" {
  count = local.create_task_exec_iam_role ? 1 : 0

  name        = var.task_exec_iam_role_use_name_prefix ? null : local.task_exec_iam_role_name
  name_prefix = var.task_exec_iam_role_use_name_prefix ? "${local.task_exec_iam_role_name}-" : null
  path        = var.task_exec_iam_role_path
  description = coalesce(var.task_exec_iam_role_description, "Task execution role for ${local.task_exec_iam_role_name}")

  #  这是一个信任策略（Trust Policy），定义了哪些实体可以“假设”该角色。通常使用 jsonencode 将 JSON 格式的信任策略编码为字符串。
  assume_role_policy    = data.aws_iam_policy_document.task_exec_assume[0].json
  max_session_duration  = var.task_exec_iam_role_max_session_duration
  permissions_boundary  = var.task_exec_iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.task_exec_iam_role_tags)
}

# aws_iam_role_policy_attachment 用于将 AWS 托管的策略（或自定义托管策略）附加到角色。托管策略适合标准化的权限配置。
# 在 AWS 中，有时候需要为一个角色赋予特定的权限，例如允许 EC2 实例访问 S3，或者让 ECS 任务访问 CloudWatch 日志。可以通过 aws_iam_role_policy_attachment 将策略附加到角色，而不需要在角色中直接定义权限。
# 这种方式的优势是可以重用策略：一个策略可以被多个角色附加，从而避免重复创建相同的权限规则。
resource "aws_iam_role_policy_attachment" "task_exec_additional" {
  for_each = { for k, v in var.task_exec_iam_role_policies : k => v if local.create_task_exec_iam_role }

  #  指定要附加策略的 IAM 角色名称或 ARN。
  role       = aws_iam_role.task_exec[0].name
  #  指定要附加的策略的 ARN。可以是 AWS 提供的托管策略，也可以是自定义的托管策略。
  policy_arn = each.value
}

# 定义policy 的文档 源
# 这里 可以输出 json 格式的 policy 文档
# 这个policy 是给task agent 使用的， 用来调用aws 的服务
data "aws_iam_policy_document" "task_exec" {
  #  count = local.create_task_exec_policy ? 1 : 0

  # Pulled from AmazonECSTaskExecutionRolePolicy
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  # Pulled from AmazonECSTaskExecutionRolePolicy
  statement {
    sid = "ECR"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.task_exec_ssm_param_arns) > 0 ? [1] : []

    content {
      sid       = "GetSSMParams"
      actions   = ["ssm:GetParameters"]
      resources = var.task_exec_ssm_param_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.task_exec_secret_arns) > 0 ? [1] : []

    content {
      sid       = "GetSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.task_exec_secret_arns
    }
  }

  #  如果你需要额外的policy, 你可以通过 var.task_exec_iam_statements 来定义
  dynamic "statement" {
    for_each = var.task_exec_iam_statements

    content {
      sid           = try(statement.value.sid, null)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, null)
      not_resources = try(statement.value.not_resources, null)

      #      在 IAM 策略 (aws_iam_policy) 的文档中，策略不能包含 Principal 字段。
      #      Principal 字段仅用于 IAM 角色信任策略，而不是 IAM 权限策略。
      #      IAM 权限策略只需要定义 Action、Effect 和 Resource 等字段。
      #      信任策略（Trust Policy）：定义了谁可以“假设”这个角色，因此需要 Principal 字段。
      #      权限策略（Permissions Policy）：定义了允许角色执行的操作，不需要 Principal 字段。
      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}
#
resource "aws_iam_policy" "task_exec" {
  count = local.create_task_exec_policy ? 1 : 0

  name        = var.task_exec_iam_role_use_name_prefix ? null : local.task_exec_iam_role_name
  name_prefix = var.task_exec_iam_role_use_name_prefix ? "${local.task_exec_iam_role_name}-" : null
  description = coalesce(var.task_exec_iam_role_description, "Task execution role IAM policy")
  policy      = data.aws_iam_policy_document.task_exec.json

  tags = merge(var.tags, var.task_exec_iam_role_tags)
}
#
resource "aws_iam_role_policy_attachment" "task_exec" {
  count = local.create_task_exec_policy ? 1 : 0

  role       = aws_iam_role.task_exec[0].name
  policy_arn = aws_iam_policy.task_exec[0].arn
}

################################################################################
# Tasks - IAM role 定义Task 的IAM Role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
################################################################################

locals {
  tasks_iam_role_name   = try(coalesce(var.tasks_iam_role_name, var.name), "")
  create_tasks_iam_role = local.create_task_definition && var.create_tasks_iam_role
}

data "aws_iam_policy_document" "tasks_assume" {
  count = local.create_tasks_iam_role ? 1 : 0

  statement {
    sid     = "ECSTasksAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#create_task_iam_policy_and_role
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "tasks" {
  count = local.create_tasks_iam_role ? 1 : 0

  name        = var.tasks_iam_role_use_name_prefix ? null : local.tasks_iam_role_name
  name_prefix = var.tasks_iam_role_use_name_prefix ? "${local.tasks_iam_role_name}-" : null
  path        = var.tasks_iam_role_path
  description = var.tasks_iam_role_description

  assume_role_policy    = data.aws_iam_policy_document.tasks_assume[0].json
  permissions_boundary  = var.tasks_iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.tasks_iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "tasks" {
  for_each = { for k, v in var.tasks_iam_role_policies : k => v if local.create_tasks_iam_role }

  role       = aws_iam_role.tasks[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "tasks" {
  count = local.create_tasks_iam_role && (length(var.tasks_iam_role_statements) > 0 || var.enable_execute_command) ? 1 : 0

  dynamic "statement" {
    for_each = var.enable_execute_command ? [1] : []

    content {
      sid = "ECSExec"
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.tasks_iam_role_statements

    content {
      sid           = try(statement.value.sid, null)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, null)
      not_resources = try(statement.value.not_resources, null)

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "tasks" {
  count = local.create_tasks_iam_role && (length(var.tasks_iam_role_statements) > 0 || var.enable_execute_command) ? 1 : 0

  name        = var.tasks_iam_role_use_name_prefix ? null : local.tasks_iam_role_name
  name_prefix = var.tasks_iam_role_use_name_prefix ? "${local.tasks_iam_role_name}-" : null
  policy      = data.aws_iam_policy_document.tasks[0].json
  role        = aws_iam_role.tasks[0].id
}

################################################################################
# Task Set
# Task Set 是 AWS ECS 中的一种概念，主要用于 ECS 的蓝/绿部署（Blue/Green Deployment），
# 特别是在使用 AWS CodeDeploy 部署服务到 Amazon ECS 时。Task Set 是一个 ECS 服务下的任务集合，
# 允许在蓝/绿部署中同时运行多个任务集（Task Set）来实现流量的无缝切换和零停机时间的更新。

#Task Set 的作用
#在 ECS 蓝/绿部署中，Task Set 是 ECS 服务管理的基础单元之一。它有以下主要作用：
#1. 支持蓝/绿部署：Task Set 允许 ECS 同时运行旧版本（蓝色任务集）和新版本（绿色任务集）以实现蓝/绿部署。在 AWS CodeDeploy 的帮助下，可以控制流量从旧版本任务集切换到新版本任务集。
#2. 流量控制：借助负载均衡器和 CodeDeploy，Task Set 可以控制流量逐步从蓝色任务集切换到绿色任务集，以确保在更新过程中没有停机时间。这种控制可以是一次性切换、金丝雀部署、线性部署等。
#3. 实现无停机更新：在 ECS 服务上部署新版本时，Task Set 允许 ECS 保持旧版本的 Task Set 运行，直到新版本完全稳定。只有当新任务集成功接管所有流量后，旧的任务集才会被终止。


#Task Set 的组成
#一个 Task Set 包含一组在 ECS 集群上运行的任务（Task）。这些任务使用相同的任务定义（Task Definition），并且在同一个 ECS 服务的上下文中管理。Task Set 有以下组成部分：
#
#1. 任务定义（Task Definition）：指定任务集中任务的容器规格、网络配置和资源要求。
#2. 负载均衡配置：如果服务是使用负载均衡的，Task Set 将会通过负载均衡器来控制流量的路由。
#3. 缩放配置：定义每个 Task Set 中任务的数量（即任务副本数），可以通过 ECS 自动伸缩来调整。

#Task Set 的生命周期
#在 ECS 蓝/绿部署的过程中，Task Set 有一个典型的生命周期：
#1. 创建新的 Task Set：在启动蓝/绿部署时，ECS 和 CodeDeploy 会创建一个新的 Task Set，用于运行应用的更新版本。
#2. 流量切换：通过负载均衡器，CodeDeploy 将流量逐步切换到新的 Task Set。可以一次性切换，也可以采用金丝雀或线性切换策略。
#3. 监控健康状态：在切换过程中，CodeDeploy 会监控新 Task Set 的健康状态，确保应用在新 Task Set 上稳定运行。
#4. 完成部署：当新的 Task Set 成功接管所有流量并被验证为稳定后，旧的 Task Set 会被终止。
#5. 删除旧的 Task Set：旧的 Task Set 完全停止并确认不再需要时，ECS 会将其删除。


#如何在 ECS 中使用 Task Set
#1. 要在 ECS 中使用 Task Set，您需要配置 ECS 服务 并选择 蓝/绿部署类型。通过使用 AWS CodeDeploy，您可以实现对 Task Set 的自动化管理和流量切换控制。以下是使用 Task Set 的基本步骤：
#2. 创建 ECS 服务：创建 ECS 服务，并配置使用 蓝/绿部署。在服务中启用负载均衡器，以便进行流量管理。
#3. 配置 AWS CodeDeploy：使用 CodeDeploy 创建部署配置（如金丝雀、线性切换等），让 CodeDeploy 可以管理 Task Set 及其流量切换。
#4. 创建新的 Task Set：在更新 ECS 服务时，CodeDeploy 会自动为新版本创建新的 Task Set。
#5. 监控和完成部署：CodeDeploy 监控新 Task Set 的健康状态并完成流量切换，确保新版本运行正常。
################################################################################

resource "aws_ecs_task_set" "this" {
  # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ecs-taskset.html
  count = local.create_task_definition && local.is_external_deployment && !var.ignore_task_definition_changes ? 1 : 0

  service         = try(aws_ecs_service.this[0].id, aws_ecs_service.ignore_task_definition[0].id)
  cluster         = var.cluster_arn
#  在 aws_ecs_task_set 中，external_id 是一个可选参数，它用于关联 CodeDeploy 部署的 部署 ID。当 aws_ecs_task_set 与 CodeDeploy 一起使用时，需要指定 external_id 以便 ECS 知道该任务集属于哪个 CodeDeploy 部署。
#  蓝/绿部署集成：在 CodeDeploy 和 ECS 结合使用蓝/绿部署时，external_id 会引用 CodeDeploy 的部署 ID，用于指向特定的部署实例。这是为了确保正确的流量控制和任务管理。
#  流量路由：CodeDeploy 在进行蓝/绿部署时会创建多个 Task Set（蓝色和绿色任务集），external_id 用于将新的 Task Set 与 CodeDeploy 部署关联，从而在流量切换时确保操作无缝衔接。
#  在配置 aws_ecs_task_set 时，external_id 需要设置为 CodeDeploy 部署的 ID。通常情况下，CodeDeploy 部署会自动生成这个 ID，您可以在 CodeDeploy 控制台找到。
  external_id     = var.external_id
#  (Required) The family and revision (family:revision) or full ARN of the task definition that you want to run in your service.
  task_definition = local.task_definition

#   The network configuration for the service. This parameter is required for task definitions that use the awsvpc network mode to receive their own Elastic Network Interface, and it is not supported for other network modes
  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [local.network_configuration] : []

    content {
#      (Required) The subnets associated with the task or service. Maximum of 16.
      assign_public_ip = network_configuration.value.assign_public_ip
#      (Optional) The security groups associated with the task or service. If you do not specify a security group, the default security group for the VPC is used. Maximum of 5.
      security_groups  = network_configuration.value.security_groups
#      (Optional) Whether to assign a public IP address to the ENI (FARGATE launch type only). Valid values are true or false. Default false.
      subnets          = network_configuration.value.subnets
    }
  }


  dynamic "load_balancer" {
    for_each = var.load_balancer

    content {
#       (Optional, Required for ELB Classic) The name of the ELB (Classic) to associate with the service.
      load_balancer_name = try(load_balancer.value.load_balancer_name, null)
#      (Optional, Required for ALB/NLB) The ARN of the Load Balancer target group to associate with the service.
      target_group_arn   = try(load_balancer.value.target_group_arn, null)
#      (Required) The name of the container to associate with the load balancer (as it appears in a container definition).
      container_name     = load_balancer.value.container_name
#      (Optional) The port on the container to associate with the load balancer. Defaults to 0 if not specified.
      container_port     = try(load_balancer.value.container_port, null)
    }
  }

  dynamic "service_registries" {
    for_each = length(var.service_registries) > 0 ? [var.service_registries] : []

    content {
      container_name = try(service_registries.value.container_name, null)
      container_port = try(service_registries.value.container_port, null)
      port           = try(service_registries.value.port, null)
      registry_arn   = service_registries.value.registry_arn
    }
  }

#  默认fargate
  launch_type = length(var.capacity_provider_strategy) > 0 ? null : var.launch_type

#  默认
  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy

    content {
      base              = try(capacity_provider_strategy.value.base, null)
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = try(capacity_provider_strategy.value.weight, null)
    }
  }

  platform_version = local.is_fargate ? var.platform_version : null

  dynamic "scale" {
    for_each = length(var.scale) > 0 ? [var.scale] : []

    content {
      unit  = try(scale.value.unit, null)
      value = try(scale.value.value, null)
    }
  }

  force_delete              = var.force_delete
  wait_until_stable         = var.wait_until_stable
  wait_until_stable_timeout = var.wait_until_stable_timeout

  tags = merge(var.tags, var.task_tags)

  lifecycle {
    ignore_changes = [
      scale, # Always ignored
    ]
  }
}

################################################################################
# Task Set - Ignore `task_definition`
################################################################################

resource "aws_ecs_task_set" "ignore_task_definition" {
  # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ecs-taskset.html
  count = local.create_task_definition && local.is_external_deployment && var.ignore_task_definition_changes ? 1 : 0

  service         = try(aws_ecs_service.this[0].id, aws_ecs_service.ignore_task_definition[0].id)
  cluster         = var.cluster_arn
  external_id     = var.external_id
  task_definition = local.task_definition

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [local.network_configuration] : []

    content {
      assign_public_ip = network_configuration.value.assign_public_ip
      security_groups  = network_configuration.value.security_groups
      subnets          = network_configuration.value.subnets
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer

    content {
      load_balancer_name = try(load_balancer.value.load_balancer_name, null)
      target_group_arn   = try(load_balancer.value.target_group_arn, null)
      container_name     = load_balancer.value.container_name
      container_port     = try(load_balancer.value.container_port, null)
    }
  }

  dynamic "service_registries" {
    for_each = length(var.service_registries) > 0 ? [var.service_registries] : []

    content {
      container_name = try(service_registries.value.container_name, null)
      container_port = try(service_registries.value.container_port, null)
      port           = try(service_registries.value.port, null)
      registry_arn   = service_registries.value.registry_arn
    }
  }

  launch_type = length(var.capacity_provider_strategy) > 0 ? null : var.launch_type

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy

    content {
      base              = try(capacity_provider_strategy.value.base, null)
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = try(capacity_provider_strategy.value.weight, null)
    }
  }

  platform_version = local.is_fargate ? var.platform_version : null

  dynamic "scale" {
    for_each = length(var.scale) > 0 ? [var.scale] : []

    content {
      unit  = try(scale.value.unit, null)
      value = try(scale.value.value, null)
    }
  }

  force_delete              = var.force_delete
  wait_until_stable         = var.wait_until_stable
  wait_until_stable_timeout = var.wait_until_stable_timeout

  tags = merge(var.tags, var.task_tags)
#ignore_changes 是 lifecycle 块的一个选项，用于指定哪些属性在 Terraform 检测到变更时应被忽略。换句话说，即使 Terraform 检测到这些属性的值发生了变化，它也不会对资源执行更新操作。
  lifecycle {
    ignore_changes = [
#      scale：这里 scale 被指定为始终忽略。这意味着，即使 scale 的值在 Terraform 配置文件中被更新，Terraform 也不会对资源执行更新操作。这种情况在 ECS 中很常见，因为任务集的 scale（即副本数量）可能会根据自动扩展策略动态变化，手动干预可能会导致意外的影响。
      scale, # Always ignored
#      指定忽略 task_definition 属性。ECS 任务集中的 task_definition 属性定义了任务的具体配置（例如镜像、CPU、内存等）。在某些情况下，您可能希望通过手动方式（或 CI/CD 管道）更新任务定义而不触发 Terraform 重新部署。如果 task_definition 属性被忽略，Terraform 将不会因为任务定义的更改而尝试更新资源。
      task_definition,
    ]
  }
}

################################################################################
# Autoscaling
################################################################################

locals {
  enable_autoscaling = local.create_service && var.enable_autoscaling && !local.is_daemon

  cluster_name = try(element(split("/", var.cluster_arn), 1), "")
}

# 应用自动缩放是一个服务，可以帮助您动态调整 AWS 资源的规模（如 ECS 服务、DynamoDB 表的吞吐量等），以满足应用程序的需求。
# aws_appautoscaling_target 定义了一个自动缩放目标，包括要缩放的资源以及最小和最大缩放容量。然后，您可以使用 aws_appautoscaling_policy 配置具体的自动缩放策略（如 CPU 使用率达到一定值时自动增加容量）。
resource "aws_appautoscaling_target" "this" {
  count = local.enable_autoscaling ? 1 : 0

  # Desired needs to be between or equal to min/max
  min_capacity = min(var.autoscaling_min_capacity, var.desired_count)
  max_capacity = max(var.autoscaling_max_capacity, var.desired_count)

  resource_id        = "service/${local.cluster_name}/${try(aws_ecs_service.this[0].name, aws_ecs_service.ignore_task_definition[0].name)}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  tags               = var.tags
}
# 自动缩放的策略
resource "aws_appautoscaling_policy" "this" {
  for_each = { for k, v in var.autoscaling_policies : k => v if local.enable_autoscaling }

  name               = try(each.value.name, each.key)
  policy_type        = try(each.value.policy_type, "TargetTrackingScaling")
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  dynamic "step_scaling_policy_configuration" {
    for_each = try([each.value.step_scaling_policy_configuration], [])

    content {
      adjustment_type          = try(step_scaling_policy_configuration.value.adjustment_type, null)
      cooldown                 = try(step_scaling_policy_configuration.value.cooldown, null)
      metric_aggregation_type  = try(step_scaling_policy_configuration.value.metric_aggregation_type, null)
      min_adjustment_magnitude = try(step_scaling_policy_configuration.value.min_adjustment_magnitude, null)

      dynamic "step_adjustment" {
        for_each = try(step_scaling_policy_configuration.value.step_adjustment, [])

        content {
          metric_interval_lower_bound = try(step_adjustment.value.metric_interval_lower_bound, null)
          metric_interval_upper_bound = try(step_adjustment.value.metric_interval_upper_bound, null)
          scaling_adjustment          = try(step_adjustment.value.scaling_adjustment, null)
        }
      }
    }
  }

  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = try(each.value.policy_type, null) == "TargetTrackingScaling" ? try([each.value.target_tracking_scaling_policy_configuration], []) : []

    content {
      dynamic "customized_metric_specification" {
        for_each = try([target_tracking_scaling_policy_configuration.value.customized_metric_specification], [])

        content {
          dynamic "dimensions" {
            for_each = try(customized_metric_specification.value.dimensions, [])

            content {
              name  = dimensions.value.name
              value = dimensions.value.value
            }
          }

          metric_name = customized_metric_specification.value.metric_name
          namespace   = customized_metric_specification.value.namespace
          statistic   = customized_metric_specification.value.statistic
          unit        = try(customized_metric_specification.value.unit, null)
        }
      }

      disable_scale_in = try(target_tracking_scaling_policy_configuration.value.disable_scale_in, null)

      dynamic "predefined_metric_specification" {
        for_each = try([target_tracking_scaling_policy_configuration.value.predefined_metric_specification], [])

        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label         = try(predefined_metric_specification.value.resource_label, null)
        }
      }

      scale_in_cooldown  = try(target_tracking_scaling_policy_configuration.value.scale_in_cooldown, 300)
      scale_out_cooldown = try(target_tracking_scaling_policy_configuration.value.scale_out_cooldown, 60)
      target_value       = try(target_tracking_scaling_policy_configuration.value.target_value, 75)
    }
  }
}

resource "aws_appautoscaling_scheduled_action" "this" {
  for_each = { for k, v in var.autoscaling_scheduled_actions : k => v if local.enable_autoscaling }

  name               = try(each.value.name, each.key)
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }

  schedule   = each.value.schedule
  start_time = try(each.value.start_time, null)
  end_time   = try(each.value.end_time, null)
  timezone   = try(each.value.timezone, null)
}

################################################################################
# Security Group
################################################################################

locals {
  create_security_group = var.create && var.create_security_group && var.network_mode == "awsvpc"
  security_group_name   = try(coalesce(var.security_group_name, var.name), "")
}

data "aws_subnet" "this" {
  count = local.create_security_group ? 1 : 0

  id = element(var.subnet_ids, 0)
}

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name        = var.security_group_use_name_prefix ? null : local.security_group_name
  name_prefix = var.security_group_use_name_prefix ? "${local.security_group_name}-" : null
  description = var.security_group_description
  vpc_id      = data.aws_subnet.this[0].vpc_id

  tags = merge(
    var.tags,
    { "Name" = local.security_group_name },
    var.security_group_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# aws_security_group_rule 用于 管理 AWS 安全组规则，即定义哪些流量可以进入（Ingress）或流出（Egress） AWS 安全组关联的资源。这些规则是安全组（aws_security_group）的核心部分，用于控制网络访问权限。
resource "aws_security_group_rule" "this" {
  for_each = { for k, v in var.security_group_rules : k => v if local.create_security_group }

  # Required
  security_group_id = aws_security_group.this[0].id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  # Optional
  description              = lookup(each.value, "description", null)
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks         = lookup(each.value, "ipv6_cidr_blocks", null)
  prefix_list_ids          = lookup(each.value, "prefix_list_ids", null)
  self                     = lookup(each.value, "self", null)
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
}
