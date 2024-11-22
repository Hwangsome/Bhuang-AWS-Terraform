locals {
  codestar_enabled = module.this.enabled && var.codestar_connection_arn != "" && var.codestar_connection_arn != null
}

# 生成project id
module "codepipeline_label" {
  source = "./modules/codepipeline_label"
  attributes = ["codepipeline"]

  context = module.this.context
}
# 生成一个默认的s3 bucket 供 codepipeline 使用
resource "aws_s3_bucket" "default" {
  count         = module.this.enabled ? 1 : 0
  bucket        = module.codepipeline_label.id
  force_destroy = var.s3_bucket_force_destroy
  tags          = module.codepipeline_label.tags
}

# 生成 assume role 的 label
module "codepipeline_assume_role_label" {
  source = "./modules/codepipeline_assume_role_label"
  attributes = ["codepipeline", "assume"]

  context = module.this.context
}

resource "aws_iam_role" "default" {
  count              = module.this.enabled ? 1 : 0
  name               = module.codepipeline_assume_role_label.id
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
#   使codepipeline 具有 aws_iam_policy_document.default,  aws_iam_policy_document.s3 的权限
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    effect = "Allow"
  }
}

# 将policy attach 到role 上
resource "aws_iam_role_policy_attachment" "default" {
  count      = module.this.enabled ? 1 : 0
  role       = join("", aws_iam_role.default.*.id)
  policy_arn = join("", aws_iam_policy.default.*.arn)
}

resource "aws_iam_policy" "default" {
  count  = module.this.enabled ? 1 : 0
  name   = module.codepipeline_label.id
  policy = data.aws_iam_policy_document.default.json
}

data "aws_iam_policy_document" "default" {
  statement {
    sid = ""
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
      "iam:PassRole"
#      add codestart permission
#      else in build stage : Error message
#      Unable to use Connection: arn:aws:codestar-connections:us-east-1:058264261029:connection/dfbc3570-0be0-4fe4-9cad-e52a705858fa. The provided role does not have sufficient permissions.
    ]

    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_role_policy" "codepipeline_cede_start" {
  name   = "codepipeline_cede_start"
  role   = aws_iam_role.default[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "codebuild:*",
          "s3:*",
          "codestar-connections:UseConnection"
        ],
        Resource = [
          "*", # 或者指定您的资源 ARN
          "arn:aws:codestar-connections:us-east-1:058264261029:connection/dfbc3570-0be0-4fe4-9cad-e52a705858fa"
        ]
      }
    ]
  })
}

# 将policy attach 到role 上
resource "aws_iam_role_policy_attachment" "s3" {
  count      = module.this.enabled ? 1 : 0
  role       = join("", aws_iam_role.default.*.id)
  policy_arn = join("", aws_iam_policy.s3.*.arn)
}

#
module "codepipeline_s3_policy_label" {
  source = "./modules/codepipeline_s3_policy_label"
  attributes = ["codepipeline", "s3"]

  context = module.this.context
}
#
resource "aws_iam_policy" "s3" {
  count  = module.this.enabled ? 1 : 0
  name   = module.codepipeline_s3_policy_label.id
  policy = join("", data.aws_iam_policy_document.s3.*.json)
}
#
data "aws_iam_policy_document" "s3" {
  count = module.this.enabled ? 1 : 0

  statement {
    sid = ""

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject"
    ]

    resources = [
      join("", aws_s3_bucket.default.*.arn),
      "${join("", aws_s3_bucket.default.*.arn)}/*"
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "codedeploy_policy" {
  name        = "CodeDeployPolicy"
  description = "IAM policy for CodeDeploy actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codedeploy:*"
        ]
        Resource = "*"
      }
    ]
  })
}

#
resource "aws_iam_role_policy_attachment" "codebuild" {
  count      = module.this.enabled ? 1 : 0
  role       = join("", aws_iam_role.default.*.id)
  policy_arn = join("", aws_iam_policy.codebuild.*.arn)
}

module "codebuild_label" {
  source     = "./modules/codebuild_label"
  attributes = ["codebuild"]

  context = module.this.context
}

resource "aws_iam_policy" "codebuild" {
  count  = module.this.enabled ? 1 : 0
  name   = module.codebuild_label.id
  policy = data.aws_iam_policy_document.codebuild.json
}
#
data "aws_iam_policy_document" "codebuild" {
  statement {
    sid = ""

    actions = [
      "codebuild:*"
    ]

    resources = [module.codebuild.project_id]
    effect    = "Allow"
  }
}


# https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-permissions.html
resource "aws_iam_role_policy_attachment" "codestar" {
  count      = local.codestar_enabled ? 1 : 0
  role       = join("", aws_iam_role.default.*.id)
  policy_arn = join("", aws_iam_policy.codestar.*.arn)
}

module "codestar_label" {
  source = "./modules/codestar_label"
  enabled    = local.codestar_enabled
  attributes = ["codestar"]

  context = module.this.context
}

resource "aws_iam_policy" "codestar" {
  count  = local.codestar_enabled ? 1 : 0
  name   = module.codestar_label.id
  policy = join("", data.aws_iam_policy_document.codestar.*.json)
}

data "aws_iam_policy_document" "codestar" {
  count = local.codestar_enabled ? 1 : 0
  statement {
    sid = ""

    actions = [
      "codestar-connections:UseConnection"
    ]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "codestar-connections:FullRepositoryId"
      values = [
        format("%s/%s", var.repo_owner, var.repo_name)
      ]
    }

    resources = [var.codestar_connection_arn]
    effect    = "Allow"

  }
}
#
data "aws_caller_identity" "default" {
}
#
data "aws_region" "default" {
}
#
module "codebuild" {
  enabled                               = module.this.enabled
  source = "./modules/codebuild"
  build_type                            = var.build_type
  build_image                           = var.build_image
  build_compute_type                    = var.build_compute_type
  build_timeout                         = var.build_timeout
  buildspec                             = var.buildspec
  delimiter                             = module.this.delimiter
  attributes                            = ["build"]
  privileged_mode                       = var.privileged_mode
  aws_region                            = var.region != "" ? var.region : data.aws_region.default.name
  aws_account_id                        = var.aws_account_id != "" ? var.aws_account_id : data.aws_caller_identity.default.account_id
  image_repo_name                       = var.image_repo_name
  image_tag                             = var.image_tag
  github_token                          = var.github_oauth_token
  environment_variables                 = var.environment_variables
  badge_enabled                         = var.badge_enabled
  cache_type                            = var.cache_type
  local_cache_modes                     = var.local_cache_modes
  secondary_artifact_location           = var.secondary_artifact_bucket_id
  secondary_artifact_identifier         = var.secondary_artifact_identifier
  secondary_artifact_encryption_enabled = var.secondary_artifact_encryption_enabled
  vpc_config                            = var.codebuild_vpc_config
  cache_bucket_suffix_enabled           = var.cache_bucket_suffix_enabled
  source_credential_token = var.github_oauth_token

  context = module.this.context
}
#
resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  count      = module.this.enabled ? 1 : 0
  role       = module.codebuild.role_id
  policy_arn = join("", aws_iam_policy.s3.*.arn)
}
#
resource "aws_iam_role_policy_attachment" "codebuild_codestar" {
  count      = local.codestar_enabled && var.codestar_output_artifact_format == "CODEBUILD_CLONE_REF" ? 1 : 0
  role       = module.codebuild.role_id
  policy_arn = join("", aws_iam_policy.codestar.*.arn)
}
#
resource "aws_iam_role_policy_attachment" "codebuild_extras" {
  for_each   = module.this.enabled ? toset(var.codebuild_extra_policy_arns) : []
  role       = module.codebuild.role_id
  policy_arn = each.value
}

# aws connect github
resource "aws_codestarconnections_connection" "github_connection" {
  name = "github-connection"
  provider_type = "GitHub"
}

# 创建 codepipeline
resource "aws_codepipeline" "default" {
  count    = module.this.enabled && var.github_oauth_token != "" ? 1 : 0
  name     = module.codepipeline_label.id
  role_arn = join("", aws_iam_role.default.*.arn)

  artifact_store {
    location = join("", aws_s3_bucket.default.*.bucket)
    type     = "S3"
  }
  pipeline_type = "V2"
  execution_mode = "QUEUED"

  depends_on = [
    aws_iam_role_policy_attachment.default,
    aws_iam_role_policy_attachment.s3,
    aws_iam_role_policy_attachment.codebuild,
    aws_iam_role_policy_attachment.codebuild_s3,
    aws_iam_role_policy_attachment.codebuild_extras
  ]

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId     = "${var.repo_owner}/${var.repo_name}"
        BranchName           = var.branch
      }
    }
  }


  #  stage {
  #    name = "Source"
  ## aws_codepipeline 的 action 块用于定义 CodePipeline 中的各个阶段的具体操作（Action），比如源码获取、构建、测试、部署等。每个 action 块是一个具体的步骤，关联了 AWS 的某个服务或操作。
  #    action {
  ##      说明：指定此操作的名称。
  #      name             = "Source"
  ##      指定此操作的类别。
  ##       Source：获取源码（例如从 S3、GitHub、CodeCommit）。
  ##       Build：构建阶段（例如 CodeBuild）。
  ##       Deploy：部署阶段（例如 CodeDeploy 或 ECS）。
  ##       Approval：手动审批阶段。
  ##       Test：测试阶段。
  #      category         = "Source"
  ##      说明：指定操作的所有者。
  ##      支持的值：
  ##       "AWS"：操作由 AWS 服务管理。
  ##       "ThirdParty"：操作由第三方服务（例如 GitHub）管理。
  ##       "Custom"：自定义操作。
  #      owner            = "ThirdParty"
  ##      说明：指定具体的服务或操作提供者。
  ##      支持的值（与 category 相关）：
  ##      Source 类别：
  ##         S3
  ##         CodeCommit
  ##         GitHub
  ##      Build 类别：
  ##         CodeBuild
  ##      Deploy 类别：
  ##         CodeDeploy
  ##         ECS
  ##      Approval 类别：
  ##         Manual
  ##      Test 类别：
  ##         CodeBuild
  #      provider         = "GitHub"
  #      version          = "1"
  ##      指定当前操作生成的输出构件。
  ##      当前操作的输出构件可以被下一个阶段或操作使用。
  #      output_artifacts = ["code"]
  #
  ##      configuration 是一个可选参数，用于定义 Action（操作）声明 的配置选项。具体来说，它允许您为某些 Action 类型（如源代码、构建、部署等）提供特定的配置信息。
  #      configuration = {
  #        OAuthToken           = var.github_oauth_token
  #        Owner                = var.repo_owner
  #        Repo                 = var.repo_name
  #        Branch               = var.branch
  #        PollForSourceChanges = var.poll_source_changes
  #      }
  #    }
  #  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      #      指定当前操作所需的输入构件。
      #      输入的构件来自上一个阶段或操作的输出。
      #      例如，Source 阶段的输出可以作为 Build 阶段的输入。
      input_artifacts  = ["SourceArtifact"]
#      DefinitionArtifact include the taskdef.json and the appspec.yaml
#      ImageArtifact include the imageDetail.json
      output_artifacts = ["ImageArtifact", "DefinitionArtifact"]

      configuration = {
        ProjectName = module.codebuild.project_name
        #        EnvironmentVariables = jsonencode([
        #          {
        #            name  = "EXAMPLE_VARIABLE"
        #            type  = "PLAINTEXT"
        #            value = "example_value"
        #          }
        #        ])
      }
    }
  }

#  https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECSbluegreen.html
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["ImageArtifact", "DefinitionArtifact"]
      version         = "1"

#      Blue/Green Deployment
#      https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECSbluegreen.html
      configuration = {
        ApplicationName     = "my-namespace-v1"
        DeploymentGroupName = "my-namespace-v1"
        TaskDefinitionTemplateArtifact = "DefinitionArtifact"
        AppSpecTemplateArtifact = "DefinitionArtifact"

      }

#      configuration = {
#        ClusterName = var.ecs_cluster_name
#        ServiceName = var.service_name
#      }
    }
  }
}

## https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html#action-reference-CodestarConnectionSource-example
# 默认不创建 这个resource
#resource "aws_codepipeline" "bitbucket" {
#  count    = local.codestar_enabled ? 1 : 0
#  name     = module.codepipeline_label.id
#  role_arn = join("", aws_iam_role.default.*.arn)
#
#  artifact_store {
#    location = join("", aws_s3_bucket.default.*.bucket)
#    type     = "S3"
#  }
#
#  depends_on = [
#    aws_iam_role_policy_attachment.default,
#    aws_iam_role_policy_attachment.s3,
#    aws_iam_role_policy_attachment.codebuild,
#    aws_iam_role_policy_attachment.codebuild_s3,
#    aws_iam_role_policy_attachment.codestar,
#    aws_iam_role_policy_attachment.codebuild_extras
#  ]
#
#  stage {
#    name = "Source"
#
#    action {
#      name             = "Source"
#      category         = "Source"
#      owner            = "AWS"
#      provider         = "CodeStarSourceConnection"
#      version          = "1"
#      output_artifacts = ["code"]
#
#      configuration = {
#        ConnectionArn        = var.codestar_connection_arn
#        FullRepositoryId     = format("%s/%s", var.repo_owner, var.repo_name)
#        BranchName           = var.branch
#        OutputArtifactFormat = var.codestar_output_artifact_format
#      }
#    }
#  }
#
#  stage {
#    name = "Build"
#
#    action {
#      name     = "Build"
#      category = "Build"
#      owner    = "AWS"
#      provider = "CodeBuild"
#      version  = "1"
#
#      input_artifacts  = ["code"]
#      output_artifacts = ["task"]
#
#      configuration = {
#        ProjectName = module.codebuild.project_name
#      }
#    }
#  }
#
#  stage {
#    name = "Deploy"
#
#    action {
#      name            = "Deploy"
#      category        = "Deploy"
#      owner           = "AWS"
#      provider        = "ECS"
#      input_artifacts = ["task"]
#      version         = "1"
#
#      configuration = {
#        ClusterName = var.ecs_cluster_name
#        ServiceName = var.service_name
#      }
#    }
#  }
#}
#
resource "random_string" "webhook_secret" {
  count  = module.this.enabled && var.webhook_enabled ? 1 : 0
  length = 32

  # Special characters are not allowed in webhook secret (AWS silently ignores webhook callbacks)
  special = false
}
#
locals {
  webhook_secret = join("", random_string.webhook_secret.*.result)
  webhook_url    = join("", aws_codepipeline_webhook.webhook.*.url)
}
#
# 用于在 AWS CodePipeline 中创建和管理 Webhook。它允许您配置管道以响应来自外部源（如 GitHub）的事件，从而实现自动化的持续集成和部署流程。
resource "aws_codepipeline_webhook" "webhook" {
  count           = module.this.enabled && var.webhook_enabled ? 1 : 0
  name            = module.codepipeline_label.id
#  Webhook 的身份验证方式。
#  "GITHUB_HMAC"：使用 GitHub HMAC 签名验证。
#  "IP"：基于 IP 地址的验证。
#  "UNAUTHENTICATED"：不进行身份验证（不推荐）。
  authentication  = var.webhook_authentication
#  Webhook 将触发的管道中的操作名称，通常是源阶段的名称。
#  target_action = "Source"
  target_action   = var.webhook_target_action
#  Webhook 所关联的 CodePipeline 的名称。
  target_pipeline = join("", aws_codepipeline.default.*.name)

#  根据选择的身份验证方式，配置相应的验证参数。
  authentication_configuration {
#    用于验证 GitHub 事件的密钥。
#    应与 GitHub Webhook 配置中的密钥一致。
    secret_token = local.webhook_secret
  }

  filter {
    json_path    = var.webhook_filter_json_path
    match_equals = var.webhook_filter_match_equals
  }
}

#module "github_webhooks" {
#  source = "./modules/github_webhooks"
#
#  enabled              = module.this.enabled && var.webhook_enabled ? true : false
#  github_repositories  = [var.repo_name]
#  webhook_url          = local.webhook_url
#  webhook_secret       = local.webhook_secret
#  webhook_content_type = "json"
#  events               = var.github_webhook_events
#
#  context = module.this.context
#}
