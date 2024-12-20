#variable "container_definition_json" {
#  type        = string
#  description = <<-EOT
#    A string containing a JSON-encoded array of container definitions
#    (`"[{ "name": "container1", ... }, { "name": "container2", ... }]"`).
#    See [API_ContainerDefinition](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html),
#    [cloudposse/terraform-aws-ecs-container-definition](https://github.com/cloudposse/terraform-aws-ecs-container-definition), or
#    [ecs_task_definition#container_definitions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition#container_definitions)
#    EOT
#}
#
#
## container
#variable "container_name" {
#  type        = string
#  description = "The name of the container. Up to 255 characters ([a-z], [A-Z], [0-9], -, _ allowed)"
#}
#
#variable "container_image" {
#  type        = string
#  description = "The image used to start the container. Images in the Docker Hub registry available by default"
#}
#
#variable "container_memory" {
#  type        = number
#  description = "The amount of memory (in MiB) to allow the container to use. This is a hard limit, if the container attempts to exceed the container_memory, the container is killed. This field is optional for Fargate launch type and the total amount of container_memory of all containers in a task will need to be lower than the task memory value"
#  default = 1024
#}
#
#variable "container_memory_reservation" {
#  type        = number
#  description = "The amount of memory (in MiB) to reserve for the container. If container needs to exceed this threshold, it can do so up to the set container_memory hard limit"
#  default = 512
#}
#
#variable "container_port_mappings" {
#  type = list(object({
#    containerPort = number
#    hostPort      = number
#    protocol      = string
#  }))
#
#  description = "The port mappings to configure for the container. This is a list of maps. Each map should contain \"containerPort\", \"hostPort\", and \"protocol\", where \"protocol\" is one of \"tcp\" or \"udp\". If using containers in a task with the awsvpc or host network mode, the hostPort can either be left blank or set to the same value as the containerPort"
#  default = [{
#    containerPort = 80
#    hostPort = 80
#    protocol = "TCP"
#  }]
#}
#
#variable "container_cpu" {
#  type        = number
#  description = "The number of cpu units to reserve for the container. This is optional for tasks using Fargate launch type and the total amount of container_cpu of all containers in a task will need to be lower than the task-level cpu value"
#  default = 1
#}
#
#variable "container_essential" {
#  type        = bool
#  description = "Determines whether all other containers in a task are stopped, if this container fails or stops for any reason. Due to how Terraform type casts booleans in json it is required to double quote this value"
#  default = true
#}
#
#variable "container_environment" {
#  type = list(object({
#    name  = string
#    value = string
#  }))
#  description = "The environment variables to pass to the container. This is a list of maps"
#  default = []
#}
#
#variable "container_readonly_root_filesystem" {
#  type        = bool
#  description = "Determines whether a container is given read-only access to its root filesystem. Due to how Terraform type casts booleans in json it is required to double quote this value"
#  default = false
#}