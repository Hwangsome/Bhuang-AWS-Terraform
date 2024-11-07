resource "random_string" "random_id" {
  length  = 8
  special = false
}



resource "aws_iam_role" "ecs_task" {
  count = local.enabled && length(var.task_role_arn) == 0 ? 1 : 0
  name = "ecs_task_iam_role"
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

  enabled             = var.iam_enabled

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