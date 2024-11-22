locals {
  enabled = module.this.enabled

  count                               = local.enabled ? 1 : 0
  id                                  = local.enabled ? join("", aws_codedeploy_app.default.*.id) : null
  name                                = local.enabled ? join("", aws_codedeploy_app.default.*.name) : null
  group_id                            = local.enabled ? join("", aws_codedeploy_deployment_group.default.*.id) : null
  deployment_config_name              = local.enabled ? join("", aws_codedeploy_deployment_config.default.*.id) : null
  deployment_config_id                = local.enabled ? join("", aws_codedeploy_deployment_config.default.*.deployment_config_id) : null
  auto_rollback_configuration_enabled = local.enabled && var.auto_rollback_configuration_events != null && length(var.auto_rollback_configuration_events) > 0
  alarm_configuration_enabled         = local.enabled && var.alarm_configuration != null
  default_sns_topic_enabled           = local.enabled && var.create_default_sns_topic
  sns_topic_arn                       = local.default_sns_topic_enabled ? module.sns_topic.sns_topic.arn : var.sns_topic_arn
  default_service_role_enabled        = local.enabled && var.create_default_service_role
  default_service_role_count          = local.default_service_role_enabled ? 1 : 0
  service_role_arn                    = local.default_service_role_enabled ? join("", aws_iam_role.default.*.arn) : var.service_role_arn
  default_policy_arn = {
    Server = "arn:${join("", data.aws_partition.current.*.partition)}:iam::aws:policy/service-role/AWSCodeDeployRole"
    Lambda = "arn:${join("", data.aws_partition.current.*.partition)}:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
    ECS    = "arn:${join("", data.aws_partition.current.*.partition)}:iam::aws:policy/AWSCodeDeployRoleForECS"
  }
}

data "aws_iam_policy_document" "assume_role" {
  count = local.default_service_role_count

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

data "aws_partition" "current" {
  count = local.default_service_role_count
}

resource "aws_iam_role" "default" {
  count              = local.default_service_role_count
  name               = module.this.id
  assume_role_policy = join("", data.aws_iam_policy_document.assume_role.*.json)
  tags               = module.this.tags
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = local.default_service_role_count
  policy_arn = format("%s", lookup(local.default_policy_arn, var.compute_platform))
  role       = join("", aws_iam_role.default.*.name)
}

module "sns_topic" {
  source  = "./sns-topic"

  enabled = local.default_sns_topic_enabled
  context = module.this.context
}

# Provides a CodeDeploy application to be used as a basis for deployments
resource "aws_codedeploy_app" "default" {
  count            = local.count
  name             = module.this.id
#  The compute platform can either be `ECS`, `Lambda`, or `Server`
  compute_platform = var.compute_platform
  tags = module.this.tags
}

#Provides a CodeDeploy deployment config for an application
# 配置code deploy的部署策略
# 创建这个资源，如果compute_platform 是EC2 你可以配置minimum_healthy_hosts
# 如果compute_platform 是ECS 你可以配置traffic_routing_config
resource "aws_codedeploy_deployment_config" "default" {
  count                  = local.count
  deployment_config_name = module.this.id
#  默认值是ECS
  compute_platform       = var.compute_platform

#  (Optional) A minimum_healthy_hosts block. Required for Server compute platform. Minimum Healthy Hosts are documented below.
#  当你选择的Compute platform 是 EC2/ON_PREMISES 时，你需要设置minimum_healthy_hosts
  dynamic "minimum_healthy_hosts" {
    for_each = var.minimum_healthy_hosts == null ? [] : [var.minimum_healthy_hosts]
    content {
#      (Required) The type can either be FLEET_PERCENT or HOST_COUNT.
#      指定在部署期间任何时候都必须可用的健康EC2实例的最小数量或百分比。
      type  = minimum_healthy_hosts.value.type
#      (Required) The value when the type is FLEET_PERCENT represents the minimum number of healthy instances as a percentage of the total number of instances in the deployment. If you specify FLEET_PERCENT, at the start of the deployment, AWS CodeDeploy converts the percentage to the equivalent number of instance and rounds up fractional instances. When the type is HOST_COUNT, the value represents the minimum number of healthy instances as an absolute value.
      value = minimum_healthy_hosts.value.value
    }
  }

#  (Optional) A traffic_routing_config block. Traffic Routing Config is documented below.
#  用于设置部署过程中流量的路由方式。对于蓝/绿部署（blue/green deployment）特别有用。
  dynamic "traffic_routing_config" {
    for_each = var.traffic_routing_config == null ? [] : [var.traffic_routing_config]

    content {
#       Type of traffic routing config. One of TimeBasedCanary, TimeBasedLinear, AllAtOnce.
#      type：支持以下类型：
#       AllAtOnce：一次性将流量切换到新的版本。
#       Canary10Percent5Minutes：切换 10% 的流量到新版本，等待 5 分钟后再切换剩下的 90%。
#       Linear10PercentEvery1Minute：每 1 分钟切换 10% 的流量到新版本，直到完成。
      type = traffic_routing_config.value.type
# (Optional) The time based linear configuration information. If type is TimeBasedCanary, use time_based_canary instead.
#    以线性方式逐步增加流量到新版本。例如，您可以配置每 1 分钟切换 10% 的流量，直到所有流量切换到新版本。
      dynamic "time_based_linear" {
        for_each = var.traffic_routing_config != null && lookup(var.traffic_routing_config, "type", null) == "TimeBasedLinear" ? [var.traffic_routing_config] : []
        content {
#          (Optional) The number of minutes between each incremental traffic shift of a TimeBasedLinear deployment.
          interval   = traffic_routing_config.value.interval
#          (Optional) The percentage of traffic that is shifted at the start of each increment of a TimeBasedLinear deployment.
          percentage = traffic_routing_config.value.percentage
        }
      }
#(Optional) The time based canary configuration information. If type is TimeBasedLinear, use time_based_linear instead.
#      逐步切换流量，首先将一小部分流量（通常是 5% 或 10%）切换到新版本，等待一段时间监控其表现，然后将剩余的流量切换到新版本。
      dynamic "time_based_canary" {
        for_each = var.traffic_routing_config != null && lookup(var.traffic_routing_config, "type", null) == "TimeBasedCanary" ? [var.traffic_routing_config] : []

        content {
#          (Optional) The number of minutes between the first and second traffic shifts of a TimeBasedCanary deployment.
          interval   = traffic_routing_config.value.interval
#           (Optional) The percentage of traffic to shift in the first increment of a TimeBasedCanary deployment.
          percentage = traffic_routing_config.value.percentage
        }
      }
    }
  }
}

resource "aws_codedeploy_deployment_group" "default" {
  count                  = local.count
#  (Required) The name of the application
#  aws_codedeploy_app.default.*.name
  app_name               = local.name
#  (Required) The name of the deployment group
  deployment_group_name  = module.this.id
#  使用你创建的deployment config
  deployment_config_name = local.deployment_config_name
#  配置code deploy 的role, 使code deploy 可以访问其他资源
  service_role_arn       = local.service_role_arn
  autoscaling_groups     = var.autoscaling_groups
# dynamic 块用于在资源或模块的配置中动态生成多个配置块。它特别适用于需要多次重复配置的情况，比如动态创建多个 security_group_rule、tag、environment_variable 等。dynamic 块能够提高代码的可读性和可维护性，减少手动重复代码。
#  配置警告, 如果你需要配置这个选项，你需要传入alarm_configuration 参数
  dynamic "alarm_configuration" {
    for_each = local.alarm_configuration_enabled ? [var.alarm_configuration] : []
#    可以将部署配置为在 CloudWatch 警报检测到指标低于或超过定义的阈值时停止。
    content {
#      (Optional) A list of alarms configured for the deployment group
      alarms                    = lookup(alarm_configuration.value, "alarms", null)
#       (Optional) Indicates whether a deployment should continue if information about the current state of alarms cannot be retrieved from CloudWatch. The default value is false.
      ignore_poll_alarm_failure = lookup(alarm_configuration.value, "ignore_poll_alarm_failure", null)
#       (Optional) Indicates whether the alarm configuration is enabled. This option is useful when you want to temporarily deactivate alarm monitoring for a deployment group without having to add the same alarms again later.
      enabled                   = local.alarm_configuration_enabled
    }
  }


#  配置自动回滚
#  可以在部署失败或满足指定的监视阈值时将部署组配置为自动回滚。在这种情况下，部署了最后一个已知的应用程序修订版。
#  这里的配置默认是当部署失败时自动回滚
#  你可以通过这个配置来设置自动回滚的事件类型
  dynamic "auto_rollback_configuration" {
    for_each = local.auto_rollback_configuration_enabled ? [1] : [0]
    content {
#      (Optional) Indicates whether a defined automatic rollback configuration is currently enabled for this Deployment Group. If you enable automatic rollback, you must specify at least one event type.
      enabled = local.auto_rollback_configuration_enabled
#      (Optional) The event type or types that trigger a rollback. Supported types are DEPLOYMENT_FAILURE, DEPLOYMENT_STOP_ON_ALARM and DEPLOYMENT_STOP_ON_REQUEST.
      events  = [var.auto_rollback_configuration_events]
    }
  }

#  配置蓝绿部署
#  这个blue_green_deployment_config 默认是null， 所以默认没有配置这个
#  如果你想配置这个，你需要传入blue_green_deployment_config 参数
  dynamic "blue_green_deployment_config" {
    for_each = var.blue_green_deployment_config == null ? [] : [var.blue_green_deployment_config]
    content {
#      (Optional) Information about the action to take when newly provisioned instances are ready to receive traffic in a blue/green deployment (documented below).
      dynamic "deployment_ready_option" {
        for_each = lookup(blue_green_deployment_config.value, "deployment_ready_option", null) == null ? [] : [lookup(blue_green_deployment_config.value, "deployment_ready_option", {})]

        content {
#          (Optional) When to reroute traffic from an original environment to a replacement environment in a blue/green deployment.
          action_on_timeout    = lookup(deployment_ready_option.value, "action_on_timeout", null)
          wait_time_in_minutes = lookup(deployment_ready_option.value, "wait_time_in_minutes", null)
        }
      }

#      green_fleet_provisioning_option 用于配置 蓝/绿部署（Blue/Green Deployment） 中绿色 环境的实例配置方式
#      绿色环境指的是新版本部署的实例集合，与旧版本的蓝色环境相对。
      dynamic "green_fleet_provisioning_option" {
        for_each = lookup(blue_green_deployment_config.value, "green_fleet_provisioning_option", null) == null ? [] : [lookup(blue_green_deployment_config.value, "green_fleet_provisioning_option", {})]
        content {
#       action：指定绿色环境的实例配置方式
          action = lookup(green_fleet_provisioning_option.value, "action", null)
        }
      }

#      蓝/绿部署成功后对原始环境中的实例采取的操作。
      dynamic "terminate_blue_instances_on_deployment_success" {
        for_each = lookup(blue_green_deployment_config.value, "terminate_blue_instances_on_deployment_success", null) == null ? [] : [lookup(blue_green_deployment_config.value, "terminate_blue_instances_on_deployment_success", {})]
        content {
#          TERMINATE：实例在指定的等待时间后终止。
#          KEEP_ALIVE：实例从负载均衡器中取消注册并从部署组中删除后仍保持运行。
          action                           = lookup(terminate_blue_instances_on_deployment_success.value, "action", null)
#          蓝/绿部署成功后，终止原始环境中的实例之前等待的分钟数。
          termination_wait_time_in_minutes = lookup(terminate_blue_instances_on_deployment_success.value, "termination_wait_time_in_minutes", null)
        }
      }
    }
  }

  dynamic "deployment_style" {
    for_each = var.deployment_style == null ? [] : [var.deployment_style]
#    deployment_option:
#    Indicates whether to route deployment traffic behind a load balancer.
#     Possible values: `WITH_TRAFFIC_CONTROL`, `WITHOUT_TRAFFIC_CONTROL`.
#     deployment_type:
#   Indicates whether to run an in-place deployment or a blue/green deployment.
#     Possible values: `IN_PLACE`, `BLUE_GREEN`.

#    In-place deployment（替换部署）通常适用于简单的更新需求，直接在现有实例上替换应用版本。
#    Blue/Green deployment（蓝/绿部署）适合对高可用性有较高要求的应用，因为它可以在不影响现有版本的情况下进行版本替换，并提供更多流量控制选项。
    content {
      deployment_option = deployment_style.value.deployment_option
      deployment_type   = deployment_style.value.deployment_type
    }
  }

  # Note that you cannot have both ec_tag_filter and ec2_tag_set vars set!
  # See https://docs.aws.amazon.com/cli/latest/reference/deploy/create-deployment-group.html for details
  dynamic "ec2_tag_filter" {
    for_each = length(var.ec2_tag_filter) > 0 ? var.ec2_tag_filter : []

    content {
      key   = lookup(ec2_tag_filter.value, "key", null)
      type  = lookup(ec2_tag_filter.value, "type", null)
      value = lookup(ec2_tag_filter.value, "value", null)
    }
  }

  # Note that you cannot have both ec_tag_filter and ec2_tag_set vars set!
  # See https://docs.aws.amazon.com/cli/latest/reference/deploy/create-deployment-group.html for details
  dynamic "ec2_tag_set" {
    for_each = length(var.ec2_tag_set) > 0 ? var.ec2_tag_set : []

    content {
      dynamic "ec2_tag_filter" {
        for_each = ec2_tag_set.value.ec2_tag_filter
        content {
          key   = lookup(ec2_tag_filter.value, "key", null)
          type  = lookup(ec2_tag_filter.value, "type", null)
          value = lookup(ec2_tag_filter.value, "value", null)
        }
      }
    }
  }

#  部署组的 ECS 服务的配置块
#  你需要输入参数 ecs_service 来配置这个
  dynamic "ecs_service" {
    for_each = var.ecs_service == null ? [] : var.ecs_service
    content {
#      ECS 集群的名称。
      cluster_name = ecs_service.value.cluster_name
#      ECS 服务的名称。
      service_name = ecs_service.value.service_name
    }
  }

#  配置要在部署中使用的负载均衡器load_balancer_info
  dynamic "load_balancer_info" {
    for_each = var.load_balancer_info == null ? [] : [var.load_balancer_info]

    content {
#      部署中使用的传统弹性负载均衡器。target_group_pair_info与target_group_info冲突。
      dynamic "elb_info" {
        for_each = lookup(load_balancer_info.value, "elb_info", null) == null ? [] : [load_balancer_info.value.elb_info]

        content {
          name = elb_info.value.name
        }
      }

#      部署中使用的（应用程序/网络负载均衡器）目标组
      dynamic "target_group_info" {
        for_each = lookup(load_balancer_info.value, "target_group_info", null) == null ? [] : [load_balancer_info.value.target_group_info]
        content {
          name = target_group_info.value.name
        }
      }
#     部署中使用的（应用程序/网络负载均衡器）目标组对
      dynamic "target_group_pair_info" {
        for_each = lookup(load_balancer_info.value, "target_group_pair_info", null) == null ? [] : [load_balancer_info.value.target_group_pair_info]

        content {

          dynamic "prod_traffic_route" {
            for_each = lookup(target_group_pair_info.value, "prod_traffic_route", null) == null ? [] : [target_group_pair_info.value.prod_traffic_route]

            content {
              listener_arns = prod_traffic_route.value.listener_arns
            }
          }

          dynamic "target_group" {
            for_each = lookup(target_group_pair_info.value, "target_group", null) == null ? [] : [target_group_pair_info.value.target_group]

            content {
              name = target_group.value.name
            }
          }

          dynamic "target_group" {
            for_each = lookup(target_group_pair_info.value, "blue_target_group", null) == null ? [] : [target_group_pair_info.value.blue_target_group]

            content {
              name = target_group.value.name
            }
          }

          dynamic "target_group" {
            for_each = lookup(target_group_pair_info.value, "green_target_group", null) == null ? [] : [target_group_pair_info.value.green_target_group]

            content {
              name = target_group.value.name
            }
          }

          dynamic "test_traffic_route" {
            for_each = lookup(target_group_pair_info.value, "test_traffic_route", null) == null ? [] : [target_group_pair_info.value.test_traffic_route]

            content {
              listener_arns = test_traffic_route.value.listener_arns
            }
          }
        }
      }
    }
  }

#  配置trigger_configuration
  dynamic "trigger_configuration" {
    for_each = local.sns_topic_arn == null ? [0] : [1]

    content {
      trigger_events     = var.trigger_events
      trigger_name       = module.this.id
      trigger_target_arn = local.sns_topic_arn
    }
  }

  tags = module.this.tags
}
