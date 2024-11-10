resource "random_string" "random_id" {
  length  = 8
  special = false
}



resource "aws_iam_role" "ecs_task" {
  count = local.enabled && length(var.task_role_arn) == 0 ? 1 : 0
  name = "ecs_task_iam_role"
  #  * 是“资源聚合”操作符，用来获取所有匹配的数据源实例的 json 属性。
  #  因为在这个代码中使用了 count，可能会存在多个 aws_iam_policy_document.ecs_task 实例，
  #  但只有在 count 大于 1 时才会真正创建多个实例。在本例中，count 的值只有两种可能：0 或 1。
  #  data.aws_iam_policy_document.ecs_task.*.json 的结果是一个包含所有 ecs_task 实例的 json 属性的列表。
  assume_role_policy   = join("", data.aws_iam_policy_document.ecs_task.*.json)
  permissions_boundary = var.permissions_boundary == "" ? null : var.permissions_boundary
  tags                 = local.ecs_tags
}
resource "aws_iam_role_policy_attachment" "ecs_task" {
  count      = local.enabled && length(var.task_role_arn) == 0 ? length(var.task_policy_arns) : 0
  policy_arn = var.task_policy_arns[count.index]
  role       = join("", aws_iam_role.ecs_task.*.id)
}

resource "aws_iam_role" "ecs_service" {
  count = local.enabled && length(var.task_role_arn) == 0 ? 1 : 0
  name                 = "ecs_service_iam_role"
  assume_role_policy   = join("", data.aws_iam_policy_document.ecs_task.*.json)
  permissions_boundary = var.permissions_boundary == "" ? null : var.permissions_boundary
  tags                 = local.ecs_service_tags
}

resource "aws_iam_role_policy" "ecs_service" {
  count  = local.enable_ecs_service_role && var.service_role_arn == null ? 1 : 0
  name   = "ecs_service_iam_policy"
  policy = join("", data.aws_iam_policy_document.ecs_service_policy.*.json)
  role   = join("", aws_iam_role.ecs_service.*.id)
}


resource "aws_iam_role" "ecs_exec" {
  count                = local.enabled && length(var.task_exec_role_arn) == 0 ? 1 : 0
  name                 = "ecs_exec_iam_role"
  assume_role_policy   = join("", data.aws_iam_policy_document.ecs_task_exec.*.json)
  permissions_boundary = var.permissions_boundary == "" ? null : var.permissions_boundary
  tags                 = local.ecs_exec_tags
}

resource "aws_iam_role_policy" "ecs_exec" {
  count  = local.enabled && length(var.task_exec_role_arn) == 0 ? 1 : 0
  name   = "ecs_exec_iam_policy"
  policy = join("", data.aws_iam_policy_document.ecs_exec.*.json)
  role   = join("", aws_iam_role.ecs_exec.*.id)
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  count      = local.enabled && length(var.task_exec_role_arn) == 0 ? length(var.task_exec_policy_arns) : 0
  policy_arn = var.task_exec_policy_arns[count.index]
  role       = join("", aws_iam_role.ecs_exec.*.id)
}

locals {

  enabled                 = module.this.enabled

  enable_ecs_service_role = true

  task_label = {
    id    = var.random_id
  }
  tags = {

  }

  ecs_tags = {

  }

  ecs_service_tags = {

  }

  ecs_exec_tags = {

  }
}