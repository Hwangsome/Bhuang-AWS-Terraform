#################################################################################
## Task Execution - IAM Role
## https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
#################################################################################
#
#locals {
#  task_exec_iam_role_name = try(coalesce(var.task_exec_iam_role_name, var.name), "")
#
#  create_task_exec_iam_role =  var.create_task_exec_iam_role
#  create_task_exec_policy   = local.create_task_exec_iam_role && var.create_task_exec_policy
#}
#
#data "aws_iam_policy_document" "task_exec_assume" {
#  count = local.create_task_exec_iam_role ? 1 : 0
#
#  statement {
#    sid     = "ECSTaskExecutionAssumeRole"
#    actions = ["sts:AssumeRole"]
#
#    principals {
#      type        = "Service"
#      identifiers = ["ecs-tasks.amazonaws.com"]
#    }
#  }
#}
#
## aws_iam_role 是一个用于创建 IAM 角色的 Terraform 资源。
##IAM 角色是一种 AWS 身份，用于允许 AWS 服务或账户访问资源，而不需要使用用户凭证。
##它具有特定的权限策略，并且只能被指定的实体（如 AWS 服务、账户或 IAM 用户）“假设”或使用。
## 这里表示 的是 ecs-tasks 服务可以假设这个角色， 执行这个role中定义的权限
#resource "aws_iam_role" "task_exec" {
#  count = local.create_task_exec_iam_role ? 1 : 0
#
#  name        = var.task_exec_iam_role_use_name_prefix ? null : local.task_exec_iam_role_name
#  name_prefix = var.task_exec_iam_role_use_name_prefix ? "${local.task_exec_iam_role_name}-" : null
#  path        = var.task_exec_iam_role_path
#  description = coalesce(var.task_exec_iam_role_description, "Task execution role for ${local.task_exec_iam_role_name}")
#
##  这是一个信任策略（Trust Policy），定义了哪些实体可以“假设”该角色。通常使用 jsonencode 将 JSON 格式的信任策略编码为字符串。
#  assume_role_policy    = data.aws_iam_policy_document.task_exec_assume.json
#  max_session_duration  = var.task_exec_iam_role_max_session_duration
#  permissions_boundary  = var.task_exec_iam_role_permissions_boundary
#  force_detach_policies = true
#
#  tags = merge(var.tags, var.task_exec_iam_role_tags)
#}
#
## aws_iam_role_policy_attachment 用于将 AWS 托管的策略（或自定义托管策略）附加到角色。托管策略适合标准化的权限配置。
## 在 AWS 中，有时候需要为一个角色赋予特定的权限，例如允许 EC2 实例访问 S3，或者让 ECS 任务访问 CloudWatch 日志。可以通过 aws_iam_role_policy_attachment 将策略附加到角色，而不需要在角色中直接定义权限。
## 这种方式的优势是可以重用策略：一个策略可以被多个角色附加，从而避免重复创建相同的权限规则。
#resource "aws_iam_role_policy_attachment" "task_exec_additional" {
#  for_each = { for k, v in var.task_exec_iam_role_policies : k => v if local.create_task_exec_iam_role }
#
##  指定要附加策略的 IAM 角色名称或 ARN。
#  role       = aws_iam_role.task_exec.name
##  指定要附加的策略的 ARN。可以是 AWS 提供的托管策略，也可以是自定义的托管策略。
#  policy_arn = each.value
#}
#
## 定义policy 的文档 源
## 这里 可以输出 json 格式的 policy 文档
## 这个policy 是给task agent 使用的， 用来调用aws 的服务
#data "aws_iam_policy_document" "task_exec" {
##  count = local.create_task_exec_policy ? 1 : 0
#
#  # Pulled from AmazonECSTaskExecutionRolePolicy
#  statement {
#    sid = "Logs"
#    actions = [
#      "logs:CreateLogStream",
#      "logs:PutLogEvents",
#    ]
#    resources = ["*"]
#  }
#
#  # Pulled from AmazonECSTaskExecutionRolePolicy
#  statement {
#    sid = "ECR"
#    actions = [
#      "ecr:GetAuthorizationToken",
#      "ecr:BatchCheckLayerAvailability",
#      "ecr:GetDownloadUrlForLayer",
#      "ecr:BatchGetImage",
#    ]
#    resources = ["*"]
#  }
#
#  dynamic "statement" {
#    for_each = length(var.task_exec_ssm_param_arns) > 0 ? [1] : []
#
#    content {
#      sid       = "GetSSMParams"
#      actions   = ["ssm:GetParameters"]
#      resources = var.task_exec_ssm_param_arns
#    }
#  }
#
#  dynamic "statement" {
#    for_each = length(var.task_exec_secret_arns) > 0 ? [1] : []
#
#    content {
#      sid       = "GetSecrets"
#      actions   = ["secretsmanager:GetSecretValue"]
#      resources = var.task_exec_secret_arns
#    }
#  }
#
##  如果你需要额外的policy, 你可以通过 var.task_exec_iam_statements 来定义
#  dynamic "statement" {
#    for_each = var.task_exec_iam_statements
#
#    content {
#      sid           = try(statement.value.sid, null)
#      actions       = try(statement.value.actions, null)
#      not_actions   = try(statement.value.not_actions, null)
#      effect        = try(statement.value.effect, null)
#      resources     = try(statement.value.resources, null)
#      not_resources = try(statement.value.not_resources, null)
#
##      在 IAM 策略 (aws_iam_policy) 的文档中，策略不能包含 Principal 字段。
##      Principal 字段仅用于 IAM 角色信任策略，而不是 IAM 权限策略。
##      IAM 权限策略只需要定义 Action、Effect 和 Resource 等字段。
##      信任策略（Trust Policy）：定义了谁可以“假设”这个角色，因此需要 Principal 字段。
##      权限策略（Permissions Policy）：定义了允许角色执行的操作，不需要 Principal 字段。
#      dynamic "principals" {
#        for_each = try(statement.value.principals, [])
#
#        content {
#          type        = principals.value.type
#          identifiers = principals.value.identifiers
#        }
#      }
#
#      dynamic "not_principals" {
#        for_each = try(statement.value.not_principals, [])
#
#        content {
#          type        = not_principals.value.type
#          identifiers = not_principals.value.identifiers
#        }
#      }
#
#      dynamic "condition" {
#        for_each = try(statement.value.conditions, [])
#
#        content {
#          test     = condition.value.test
#          values   = condition.value.values
#          variable = condition.value.variable
#        }
#      }
#    }
#  }
#}
##
#resource "aws_iam_policy" "task_exec" {
#  count = local.create_task_exec_policy ? 1 : 0
#
#  name        = var.task_exec_iam_role_use_name_prefix ? null : local.task_exec_iam_role_name
#  name_prefix = var.task_exec_iam_role_use_name_prefix ? "${local.task_exec_iam_role_name}-" : null
#  description = coalesce(var.task_exec_iam_role_description, "Task execution role IAM policy")
#  policy      = data.aws_iam_policy_document.task_exec.json
#
#  tags = merge(var.tags, var.task_exec_iam_role_tags)
#}
##
#resource "aws_iam_role_policy_attachment" "task_exec" {
#  count = local.create_task_exec_policy ? 1 : 0
#
#  role       = aws_iam_role.task_exec.name
#  policy_arn = aws_iam_policy.task_exec.arn
#}
#
#
#locals {
#  tasks_iam_role_name   = try(coalesce(var.tasks_iam_role_name, var.name), "")
#  create_tasks_iam_role = local.create_task_definition && var.create_tasks_iam_role
#}
#
#data "aws_iam_policy_document" "tasks_assume" {
#  count = local.create_tasks_iam_role ? 1 : 0
#
#  statement {
#    sid     = "ECSTasksAssumeRole"
#    actions = ["sts:AssumeRole"]
#
#    principals {
#      type        = "Service"
#      identifiers = ["ecs-tasks.amazonaws.com"]
#    }
#
#    # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#create_task_iam_policy_and_role
#    condition {
#      test     = "ArnLike"
#      variable = "aws:SourceArn"
#      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
#    }
#
#    condition {
#      test     = "StringEquals"
#      variable = "aws:SourceAccount"
#      values   = [local.account_id]
#    }
#  }
#}
#
#resource "aws_iam_role" "tasks" {
#  count = local.create_tasks_iam_role ? 1 : 0
#
#  name        = var.tasks_iam_role_use_name_prefix ? null : local.tasks_iam_role_name
#  name_prefix = var.tasks_iam_role_use_name_prefix ? "${local.tasks_iam_role_name}-" : null
#  path        = var.tasks_iam_role_path
#  description = var.tasks_iam_role_description
#
#  assume_role_policy    = data.aws_iam_policy_document.tasks_assume[0].json
#  permissions_boundary  = var.tasks_iam_role_permissions_boundary
#  force_detach_policies = true
#
#  tags = merge(var.tags, var.tasks_iam_role_tags)
#}
#
#resource "aws_iam_role_policy_attachment" "tasks" {
#  for_each = { for k, v in var.tasks_iam_role_policies : k => v if local.create_tasks_iam_role }
#
#  role       = aws_iam_role.tasks[0].name
#  policy_arn = each.value
#}
#
#data "aws_iam_policy_document" "tasks" {
#  count = local.create_tasks_iam_role && (length(var.tasks_iam_role_statements) > 0 || var.enable_execute_command) ? 1 : 0
#
#  dynamic "statement" {
#    for_each = var.enable_execute_command ? [1] : []
#
#    content {
#      sid = "ECSExec"
#      actions = [
#        "ssmmessages:CreateControlChannel",
#        "ssmmessages:CreateDataChannel",
#        "ssmmessages:OpenControlChannel",
#        "ssmmessages:OpenDataChannel",
#      ]
#      resources = ["*"]
#    }
#  }
#
#  dynamic "statement" {
#    for_each = var.tasks_iam_role_statements
#
#    content {
#      sid           = try(statement.value.sid, null)
#      actions       = try(statement.value.actions, null)
#      not_actions   = try(statement.value.not_actions, null)
#      effect        = try(statement.value.effect, null)
#      resources     = try(statement.value.resources, null)
#      not_resources = try(statement.value.not_resources, null)
#
#      dynamic "principals" {
#        for_each = try(statement.value.principals, [])
#
#        content {
#          type        = principals.value.type
#          identifiers = principals.value.identifiers
#        }
#      }
#
#      dynamic "not_principals" {
#        for_each = try(statement.value.not_principals, [])
#
#        content {
#          type        = not_principals.value.type
#          identifiers = not_principals.value.identifiers
#        }
#      }
#
#      dynamic "condition" {
#        for_each = try(statement.value.conditions, [])
#
#        content {
#          test     = condition.value.test
#          values   = condition.value.values
#          variable = condition.value.variable
#        }
#      }
#    }
#  }
#}
#
#resource "aws_iam_role_policy" "tasks" {
#  count = local.create_tasks_iam_role && (length(var.tasks_iam_role_statements) > 0 || var.enable_execute_command) ? 1 : 0
#
#  name        = var.tasks_iam_role_use_name_prefix ? null : local.tasks_iam_role_name
#  name_prefix = var.tasks_iam_role_use_name_prefix ? "${local.tasks_iam_role_name}-" : null
#  policy      = data.aws_iam_policy_document.tasks[0].json
#  role        = aws_iam_role.tasks[0].id
#}


################################################################################
# Tasks - IAM role 定义Task 的IAM Role
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
################################################################################
#data "aws_region" "current" {}
#data "aws_partition" "current" {}
#data "aws_caller_identity" "current" {}
#
#locals {
#  tasks_iam_role_name   = try(coalesce(var.tasks_iam_role_name, var.name), "")
#  create_tasks_iam_role =  var.create_tasks_iam_role
#  account_id = data.aws_caller_identity.current.account_id
#  partition  = data.aws_partition.current.partition
#  region     = data.aws_region.current.name
#}
#
#data "aws_iam_policy_document" "tasks_assume" {
#  count = local.create_tasks_iam_role ? 1 : 0
#
#  statement {
#    sid     = "ECSTasksAssumeRole"
#    actions = ["sts:AssumeRole"]
#
#    principals {
#      type        = "Service"
#      identifiers = ["ecs-tasks.amazonaws.com"]
#    }
#
#    # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html#create_task_iam_policy_and_role
#    condition {
#      test     = "ArnLike"
#      variable = "aws:SourceArn"
#      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
#    }
#
#    condition {
#      test     = "StringEquals"
#      variable = "aws:SourceAccount"
#      values   = [local.account_id]
#    }
#  }
#}
#
#resource "aws_iam_role" "tasks" {
#  count = local.create_tasks_iam_role ? 1 : 0
#
#  name        = var.tasks_iam_role_use_name_prefix ? null : local.tasks_iam_role_name
#  name_prefix = var.tasks_iam_role_use_name_prefix ? "${local.tasks_iam_role_name}-" : null
#  path        = var.tasks_iam_role_path
#  description = var.tasks_iam_role_description
#
#  assume_role_policy    = data.aws_iam_policy_document.tasks_assume[0].json
#  permissions_boundary  = var.tasks_iam_role_permissions_boundary
#  force_detach_policies = true
#
#  tags = merge(var.tags, var.tasks_iam_role_tags)
#}
#
#resource "aws_iam_role_policy_attachment" "tasks" {
#  for_each = { for k, v in var.tasks_iam_role_policies : k => v if local.create_tasks_iam_role }
#
#  role       = aws_iam_role.tasks[0].name
#  policy_arn = each.value
#}
#
#data "aws_iam_policy_document" "tasks" {
#  count = local.create_tasks_iam_role && (length(var.tasks_iam_role_statements) > 0 || var.enable_execute_command) ? 1 : 0
#
#  dynamic "statement" {
#    for_each = var.enable_execute_command ? [1] : []
#
#    content {
#      sid = "ECSExec"
#      actions = [
#        "ssmmessages:CreateControlChannel",
#        "ssmmessages:CreateDataChannel",
#        "ssmmessages:OpenControlChannel",
#        "ssmmessages:OpenDataChannel",
#      ]
#      resources = ["*"]
#    }
#  }
#
#  dynamic "statement" {
#    for_each = var.tasks_iam_role_statements
#
#    content {
#      sid           = try(statement.value.sid, null)
#      actions       = try(statement.value.actions, null)
#      not_actions   = try(statement.value.not_actions, null)
#      effect        = try(statement.value.effect, null)
#      resources     = try(statement.value.resources, null)
#      not_resources = try(statement.value.not_resources, null)
#
#      dynamic "principals" {
#        for_each = try(statement.value.principals, [])
#
#        content {
#          type        = principals.value.type
#          identifiers = principals.value.identifiers
#        }
#      }
#
#      dynamic "not_principals" {
#        for_each = try(statement.value.not_principals, [])
#
#        content {
#          type        = not_principals.value.type
#          identifiers = not_principals.value.identifiers
#        }
#      }
#
#      dynamic "condition" {
#        for_each = try(statement.value.conditions, [])
#
#        content {
#          test     = condition.value.test
#          values   = condition.value.values
#          variable = condition.value.variable
#        }
#      }
#    }
#  }
#}
#
#resource "aws_iam_role_policy" "tasks" {
#  count = local.create_tasks_iam_role && (length(var.tasks_iam_role_statements) > 0 || var.enable_execute_command) ? 1 : 0
#
#  name        = var.tasks_iam_role_use_name_prefix ? null : local.tasks_iam_role_name
#  name_prefix = var.tasks_iam_role_use_name_prefix ? "${local.tasks_iam_role_name}-" : null
#  policy      = data.aws_iam_policy_document.tasks[0].json
#  role        = aws_iam_role.tasks[0].id
#}


################################################################################
# Autoscaling
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