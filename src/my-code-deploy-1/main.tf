module "code-deploy" {
  source  = "cloudposse/code-deploy/aws"
  version = "0.2.3"
  # insert the 21 required variables here
  additional_tag_map = {

  }
  alarm_configuration = {
    alarms                    = var.alarm_configuration.alarms
    ignore_poll_alarm_failure = var.alarm_configuration.ignore_poll_alarm_failure
  }

  attributes = []

  # The event type or types that trigger a rollback. Supported types are DEPLOYMENT_FAILURE and DEPLOYMENT_STOP_ON_ALARM.
  auto_rollback_configuration_events = "DEPLOYMENT_FAILURE"

  # A list of Autoscaling Groups associated with the deployment group.
  autoscaling_groups = []

  # this type is any
  # Configuration block of the blue/green deployment options for a deployment group,
  #see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group#blue_green_deployment_config
  blue_green_deployment_config = []

  # The compute platform can either be ECS, Lambda, or Server
  # default is ECS
  compute_platform = "ECS"

  # Single object for setting entire context at once.
  #See description of individual variables for details.
  #Leave string and numeric variables as null to use default value.
  #Individual variable settings (non-null) override settings in context object,
  #except for attributes, tags, and additional_tag_map, which are merged.
  context = {}

  # Whether to create default IAM role ARN that allows deployments.
  # default is true
  create_default_service_role = true

  # Whether to create default SNS topic through which notifications are sent.
  # default is true
  create_default_sns_topic = true

  # Delimiter to be used between ID elements.
  # Defaults to `-` (hyphen). Set to `""` to use no delimiter at all.
  delimiter = "-"

  # Configuration of the type of deployment, either in-place or blue/green,
  #you want to run and whether to route deployment traffic behind a load balancer.
  #
  #deployment_option:
  #Indicates whether to route deployment traffic behind a load balancer.
  #Possible values: WITH_TRAFFIC_CONTROL, WITHOUT_TRAFFIC_CONTROL.
  #deployment_type:
  #Indicates whether to run an in-place deployment or a blue/green deployment.
  #Possible values: IN_PLACE, BLUE_GREEN.
  deployment_style = {
    deployment_option = ""
    deployment_type = "BLUE_GREEN"

  }

  descriptor_formats = {

  }

  # The Amazon EC2 tags on which to filter. The deployment group includes EC2 instances with any of the specified tags.
  #    Cannot be used in the same call as ec2TagSet.
  ec2_tag_filter = []

  # A list of sets of tag filters. If multiple tag groups are specified,
  #    any instance that matches to at least one tag filter of every tag group is selected.
  #
  #    key:
  #      The key of the tag filter.
  #    type:
  #      The type of the tag filter, either `KEY_ONLY`, `VALUE_ONLY`, or `KEY_AND_VALUE`.
  #    value:
  #      The value of the tag filter.
  ec2_tag_set = []

  # Configuration block(s) of the ECS services for a deployment group.
  #
  #cluster_name:
  #The name of the ECS cluster.
  #service_name:
  #The name of the ECS service.
  ecs_service = [
    {
      cluster_name = ""
      service_name = ""
    }
  ]

  # Set to false to prevent the module from creating any resources
  enabled = false

  # ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT'"
  environment = ""

  # Controls the letter case of the `tags` keys (label names) for tags generated by this module.
  #    Does not affect keys of tags passed in via the `tags` input.
  #    Possible values: `lower`, `title`, `upper`.
  #    Default value: `title`.
  label_key_case = ""

  label_order = []

  # Controls the letter case of ID elements (labels) as included in `id`,
  #    set as tag values, and output by this module individually.
  #    Does not affect values of tags passed in via the `tags` input.
  #    Possible values: `lower`, `title`, `upper` and `none` (no transformation).
  #    Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.
  #    Default value: `lower`.
  label_value_case = ""

  labels_as_tags = []

  load_balancer_info = {}

  # type:
  #The type can either be FLEET_PERCENT or HOST_COUNT.
  #value:
  #The value when the type is FLEET_PERCENT represents the minimum number of healthy instances
  #as a percentage of the total number of instances in the deployment.
  #When the type is HOST_COUNT, the value represents the minimum number of healthy instances as an absolute value.
  minimum_healthy_hosts = []

  # ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.
  #This is the only ID element not also included as a tag.
  #The "name" tag is set to the full id string. There is no tag with the value of the name input.
  name = ""

  # ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique
  namespace = ""

  # Terraform regular expression (regex) string.
  #Characters matching the regex will be removed from the ID elements.
  #If not set, "/[^a-zA-Z0-9-]/" is used to remove all characters other than hyphens, letters and digits.
  regex_replace_chars = ""

  # The service IAM role ARN that allows deployments.
  service_role_arn = ""

  # The ARN of the SNS topic through which notifications are sent.
  sns_topic_arn = ""

#   ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release'
  stage = ""

  # Additional tags (e.g. {'BusinessUnit': 'XYZ'}).
  #Neither the tag keys nor the tag values will be modified by this module.
  tags = {}

  # ID element _(Rarely used, not included by default)_. A customer identifier, indicating who this instance of a resource is for"
  tenant = ""

  traffic_routing_config = ()

  trigger_events = []


}