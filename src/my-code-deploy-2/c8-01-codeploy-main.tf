#module "code-deploy" {
#  source  = "cloudposse/code-deploy/aws"
#  version = "0.2.3"
#  # insert the 21 required variables here
#  ecs_service = {
#    cluster = "terraform-cluster"
#    service = "terraform-test-task-definition"
#  }
#
#}


module "code_deploy_blue_green" {
  source  = "cloudposse/code-deploy/aws"
  version = "0.2.3"
#  context = module.this.context

  minimum_healthy_hosts = null

  traffic_routing_config = {
    type       = "TimeBasedLinear"
    interval   = 10
    percentage = 10
  }

  deployment_style = {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config = {
    deployment_ready_option = {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 10
    }
    terminate_blue_instances_on_deployment_success = {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service = [{
    cluster_name = "terraform-cluster"
    service_name = "terraform-test-task-definition"
  }]


  load_balancer_info = {
    target_group_pair_info = {
      prod_traffic_route = {
        listener_arns = [module.alb.listeners["blue_http"].arn]
      }
      blue_target_group = {
        name = module.alb.target_groups["blue_env"].arn
      }
      green_target_group = {
        name = module.alb.target_groups["green_env"].arn
      }
    }
  }
  namespace = var.namespace
  stage = var.stage
}

variable "context" {
  type = any
  default = {
    enabled             = true
    namespace           = null
    tenant              = null
    environment         = null
    stage               = null
    name                = null
    delimiter           = null
    attributes          = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = null
    label_order         = []
    id_length_limit     = null
    label_key_case      = null
    label_value_case    = null
    descriptor_formats  = {}
    # Note: we have to use [] instead of null for unset lists due to
    # https://github.com/hashicorp/terraform/issues/28137
    # which was not fixed until Terraform 1.0.0,
    # but we want the default to be all the labels in `label_order`
    # and we want users to be able to prevent all tag generation
    # by setting `labels_as_tags` to `[]`, so we need
    # a different sentinel to indicate "default"
    labels_as_tags = ["unset"]
  }
  description = <<-EOT
    Single object for setting entire context at once.
    See description of individual variables for details.
    Leave string and numeric variables as `null` to use default value.
    Individual variable settings (non-null) override settings in context object,
    except for attributes, tags, and additional_tag_map, which are merged.
  EOT

  validation {
    condition     = lookup(var.context, "label_key_case", null) == null ? true : contains(["lower", "title", "upper"], var.context["label_key_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`."
  }

  validation {
    condition     = lookup(var.context, "label_value_case", null) == null ? true : contains(["lower", "title", "upper", "none"], var.context["label_value_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`, `none`."
  }
}

variable "namespace" {
  default = "my-namespace" # 长度 12
}

variable "stage" {
  default = "v1" # 长度 2
}

variable "name" {
  default = "my-codedeploy-app" # 长度 19
}
