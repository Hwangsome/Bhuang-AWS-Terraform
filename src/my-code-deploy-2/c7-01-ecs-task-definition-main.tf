module "container_definition" {
  source = "./modules/container_definition"
  container_name               = var.container_name
  container_image              = var.container_image
  container_memory             = var.container_memory
  container_memory_reservation = var.container_memory_reservation
  container_cpu                = var.container_cpu
  essential                    = var.container_essential
  readonly_root_filesystem     = var.container_readonly_root_filesystem
  environment                  = var.container_environment
  port_mappings                = var.container_port_mappings
}

resource "aws_ecs_task_definition" "default" {
  family                   = "aws_ecs_task_definition"
  container_definitions    = module.container_definition.json_map_encoded_list
#  The launch type on which to run your service. Valid values are `EC2` and `FARGATE`
  requires_compatibilities = [var.launch_type]
#  The network mode to use for the task. This is required to be `awsvpc` for `FARGATE` `launch_type` or `null` for `EC2` `launch_type`
  network_mode             = var.network_mode
# the number of CPU units used by the task. If using `FARGATE` launch type `task_cpu` must match [supported memory values](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
  cpu                      = var.task_cpu
#  The amount of memory (in MiB) used by the task. If using Fargate launch type `task_memory` must match [supported cpu value](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
  memory                   = var.task_memory
#  The ARN of IAM role that allows the ECS/Fargate agent to make calls to the ECS API on your behalf"
  execution_role_arn       = length(var.task_exec_role_arn) > 0 ? var.task_exec_role_arn : join("", aws_iam_role.ecs_exec.*.arn)
#  The ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services"
#  task_role_arn            = length(var.task_role_arn) > 0 ? var.task_role_arn : join("", aws_iam_role.ecs_task.*.arn)
  task_role_arn            = length(var.task_role_arn) > 0 ? var.task_role_arn : join("", aws_iam_role.ecs_task.*.arn)


  dynamic "placement_constraints" {
    for_each = var.task_placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = lookup(placement_constraints.value, "expression", null)
    }
  }

  dynamic "volume" {
#    volumes 是一个数组类型， 数组里面的内容是map
#    lookup(map, key, default)
#    map：必需。要查找的映射（map），比如一个包含键值对的变量。
#    key：必需。要检索的键名称。
#   default：必需。当 key 不存在于 map 中时返回的默认值。
    for_each = var.volumes
    content {
      host_path = lookup(volume.value, "host_path", null)
      name      = volume.value.name

      dynamic "docker_volume_configuration" {
        for_each = lookup(volume.value, "docker_volume_configuration", [])
        content {
          #          If this value is true, the Docker volume is created if it does not already exist. Note: This field is only used if the scope is shared.
          autoprovision = lookup(docker_volume_configuration.value, "autoprovision", null)
          #           Docker volume driver to use. The driver value must match the driver name provided by Docker because it is used for task placement.
          driver        = lookup(docker_volume_configuration.value, "driver", null)
          #          Map of Docker driver specific options.
          driver_opts   = lookup(docker_volume_configuration.value, "driver_opts", null)
          #           Map of custom metadata to add to your Docker volume.
          labels        = lookup(docker_volume_configuration.value, "labels", null)
          #           Scope for the Docker volume, which determines its lifecycle, either task or shared. Docker volumes that are scoped to a task are automatically provisioned when the task starts and destroyed when the task stops. Docker volumes that are scoped as shared persist after the task stops.
          scope         = lookup(docker_volume_configuration.value, "scope", null)
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          #          (Required) ID of the EFS File System.
          file_system_id          = lookup(efs_volume_configuration.value, "file_system_id", null)
          #          (Optional) Directory within the Amazon EFS file system to mount as the root directory inside the host. If this parameter is omitted, the root of the Amazon EFS volume will be used. Specifying / will have the same effect as omitting this parameter. This argument is ignored when using authorization_config.
          root_directory          = lookup(efs_volume_configuration.value, "root_directory", null)
          #          (Optional) Whether or not to enable encryption for Amazon EFS data in transit between the Amazon ECS host and the Amazon EFS server. Transit encryption must be enabled if Amazon EFS IAM authorization is used. Valid values: ENABLED, DISABLED. If this parameter is omitted, the default value of DISABLED is used.
          transit_encryption      = lookup(efs_volume_configuration.value, "transit_encryption", null)
          #          (Optional) Port to use for transit encryption. If you do not specify a transit encryption port, it will use the port selection strategy that the Amazon EFS mount helper uses.
          transit_encryption_port = lookup(efs_volume_configuration.value, "transit_encryption_port", null)
          #           (Optional) Configuration block for authorization for the Amazon EFS file system. Detailed below.
          dynamic "authorization_config" {
            for_each = lookup(efs_volume_configuration.value, "authorization_config", [])
            content {
              #              (Optional) Access point ID to use. If an access point is specified, the root directory value will be relative to the directory set for the access point. If specified, transit encryption must be enabled in the EFSVolumeConfiguration.
              access_point_id = lookup(authorization_config.value, "access_point_id", null)
              #              Optional) Whether or not to use the Amazon ECS task IAM role defined in a task definition when mounting the Amazon EFS file system. If enabled, transit encryption must be enabled in the EFSVolumeConfiguration. Valid values: ENABLED, DISABLED. If this parameter is omitted, the default value of DISABLED is used.
              iam             = lookup(authorization_config.value, "iam", null)
            }
          }
        }
      }
    }
  }
  tags = var.use_old_arn ? null : module.this.tags

}