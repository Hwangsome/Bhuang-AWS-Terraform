data "aws_caller_identity" "default" {}



data "aws_region" "default" {}

# aws_s3_bucket_acl 资源用于管理 Amazon S3 存储桶的访问控制列表（ACL）。
# ACL 是一种用于定义 S3 存储桶及其对象的访问权限的简单方法。它决定了谁可以访问存储桶及其内容，以及可以执行哪些操作（如读、写、列表等）。
#使用场景
#   修改 S3 存储桶的权限：
#     通过 ACL 设置存储桶的公开访问或私有访问。
#   为特定用户或账户授予权限：
#     通过 ACL 授予 AWS 账户或公共用户（如匿名访问）权限。
#   灵活控制权限与安全性：
#     确保 S3 存储桶符合应用的安全性需求，例如遵循最小权限原则。
resource "aws_s3_bucket_acl" "default" {
  count      = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
#  bucket：指定要应用 ACL 的 S3 存储桶名称。
  bucket     = join("", resource.aws_s3_bucket.cache_bucket[*].id)
#  acl：指定要应用的 ACL 类型，例如 private, public-read。
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

# debug variable
output "enable" {
  value = module.this.enabled
}
output "create_s3_cache_bucket" {
  value = local.create_s3_cache_bucket
}

# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket_versioning" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)
  versioning_configuration {
    status = "Enabled"
  }
}
# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket_lifecycle_configuration" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  rule {
    id     = "codebuildcache"
    status = "Enabled"

    filter {
      prefix = "/"
    }

    expiration {
      days = var.cache_expiration_days
    }
  }
}
# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket_logging" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket && var.access_log_bucket_name != "" ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  target_bucket = var.access_log_bucket_name
  target_prefix = "logs/${module.this.id}/"
}
# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket_public_access_block" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# create_s3_cache_bucket 为false 不会创建这个资源
resource "aws_s3_bucket" "cache_bucket" {
  #bridgecrew:skip=BC_AWS_S3_13:Skipping `Enable S3 Bucket Logging` check until bridgecrew will support dynamic blocks (https://github.com/bridgecrewio/checkov/issues/776).
  #bridgecrew:skip=BC_AWS_S3_14:Skipping `Ensure all data stored in the S3 bucket is securely encrypted at rest` check until bridgecrew will support dynamic blocks (https://github.com/bridgecrewio/checkov/issues/776).
  #bridgecrew:skip=CKV_AWS_52:Skipping `Ensure S3 bucket has MFA delete enabled` due to issue in terraform (https://github.com/hashicorp/terraform-provider-aws/issues/629).
  count         = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket        = local.cache_bucket_name_normalised
  force_destroy = true
  tags          = module.this.tags
}
#
resource "random_string" "bucket_prefix" {
  count   = module.this.enabled ? 1 : 0
  length  = 12
  numeric = false
  upper   = false
  special = false
  lower   = true
}
#
locals {
  cache_bucket_name = "${module.this.id}${var.cache_bucket_suffix_enabled ? "-${join("", random_string.bucket_prefix[*].result)}" : ""}"

  ## Clean up the bucket name to use only hyphens, and trim its length to 63 characters.
  ## As per https://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html
  cache_bucket_name_normalised = substr(
    join("-", split("_", lower(local.cache_bucket_name))),
    0,
    min(length(local.cache_bucket_name), 63),
  )

  s3_cache_enabled       = var.cache_type == "S3"
  create_s3_cache_bucket = local.s3_cache_enabled && var.s3_cache_bucket_name == null
  s3_bucket_name         = local.create_s3_cache_bucket ? join("", aws_s3_bucket.cache_bucket[*].bucket) : var.s3_cache_bucket_name

  aws_region     = signum(length(var.aws_region)) == 1 ? var.aws_region : data.aws_region.default.name
  aws_account_id = signum(length(var.aws_account_id)) == 1 ? var.aws_account_id : data.aws_caller_identity.default.account_id

  ## This is the magic where a map of a list of maps is generated
  ## and used to conditionally add the cache bucket option to the
  ## aws_codebuild_project
  cache_options = {
    "S3" = {
      type     = "S3"
      location = module.this.enabled && local.s3_cache_enabled ? local.s3_bucket_name : "none"
    },
    "LOCAL" = {
      type  = "LOCAL"
      modes = var.local_cache_modes
    },
    "NO_CACHE" = {
      type = "NO_CACHE"
    }
  }

  # Final Map Selected from above
  cache = local.cache_options[var.cache_type]
}
####################################
# IAM
####################################
# create role
resource "aws_iam_role" "default" {
  count                 = module.this.enabled ? 1 : 0
  name                  = module.this.id
  assume_role_policy    = data.aws_iam_policy_document.role.json
  force_detach_policies = true
  path                  = var.iam_role_path
  permissions_boundary  = var.iam_permissions_boundary
  tags                  = module.this.tags
}

###########################
# debug variable
###########################
output "module_id" {
  value = module.this.id
}

data "aws_iam_policy_document" "role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      # to avoid cyclic dependencies with codebuild, we can't reference
      # the resources arn directly instead we interpolate the arn using known values
      values = [
        "arn:aws:codebuild:${local.aws_region}:${local.aws_account_id}:project/${module.this.id}"
      ]
    }

    effect = "Allow"
  }
}
# create default policy
resource "aws_iam_policy" "default" {
  count  = module.this.enabled ? 1 : 0
  name   = module.this.id
  path   = var.iam_policy_path
  policy = data.aws_iam_policy_document.combined_permissions.json
  tags   = module.this.tags
}


#
resource "aws_iam_policy" "default_cache_bucket" {
  count = module.this.enabled && local.s3_cache_enabled ? 1 : 0

  name   = "${module.this.id}-cache-bucket"
  path   = var.iam_policy_path
  policy = join("", data.aws_iam_policy_document.permissions_cache_bucket[*].json)
  tags   = module.this.tags
}
#
data "aws_s3_bucket" "secondary_artifact" {
  count  = module.this.enabled ? (var.secondary_artifact_location != null ? 1 : 0) : 0
  bucket = var.secondary_artifact_location
}
#
data "aws_iam_policy_document" "permissions" {
  count = module.this.enabled ? 1 : 0

  dynamic "statement" {
    for_each = var.default_permissions_enabled ? [1] : []

    content {
      sid = ""

      actions = compact(concat([
        "codecommit:GitPull",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecs:RunTask",
        "iam:PassRole",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ssm:GetParameters",
        "secretsmanager:GetSecretValue",
#        拉取 ecr 中的镜像
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ], var.extra_permissions))

      effect = "Allow"

      resources = [
        "*",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.secondary_artifact_location != null ? [1] : []
    content {
      sid = ""

      actions = [
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ]

      effect = "Allow"

      resources = [
        join("", data.aws_s3_bucket.secondary_artifact[*].arn),
        "${join("", data.aws_s3_bucket.secondary_artifact[*].arn)}/*",
      ]
    }
  }

  lifecycle {
    precondition {
      condition     = length(var.extra_permissions) > 0 ? var.default_permissions_enabled : true
      error_message = <<-EOT
      Extra permissions can only be attached to the default permissions policy statement.
      Either set `default_permissions_enabled` to true or use `custom_policy` to set a least privileged policy."
      EOT
    }
  }
}
#
data "aws_iam_policy_document" "vpc_permissions" {
  count = module.this.enabled && var.vpc_config != {} ? 1 : 0

  statement {
    sid = ""

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = ""

    actions = [
      "ec2:CreateNetworkInterfacePermission"
    ]

    resources = [
      "arn:aws:ec2:${local.aws_region}:${local.aws_account_id}:network-interface/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"
      values = formatlist(
        "arn:aws:ec2:${local.aws_region}:${local.aws_account_id}:subnet/%s",
        var.vpc_config.subnets
      )
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values = [
        "codebuild.amazonaws.com"
      ]
    }

  }
}
# merge custom_policy, default_permissions_enabled, extra_permissions, vpc_config
data "aws_iam_policy_document" "combined_permissions" {
  override_policy_documents = compact([
    join("", var.custom_policy),
    join("", data.aws_iam_policy_document.permissions[*].json),
    var.vpc_config != {} ? join("", data.aws_iam_policy_document.vpc_permissions[*].json) : null
  ])
}
output "combined_permissions" {
  value = data.aws_iam_policy_document.combined_permissions.json
}


#
data "aws_iam_policy_document" "permissions_cache_bucket" {
  count = module.this.enabled && local.s3_cache_enabled ? 1 : 0
  statement {
    sid = ""

    actions = [
      "s3:*",
    ]

    effect = "Allow"

    resources = [
      join("", aws_s3_bucket.cache_bucket[*].arn),
      "${join("", aws_s3_bucket.cache_bucket[*].arn)}/*",
    ]
  }
}

# 将policy attach 到 role中
resource "aws_iam_role_policy_attachment" "default" {
  count      = module.this.enabled ? 1 : 0
  policy_arn = join("", aws_iam_policy.default[*].arn)
  role       = join("", aws_iam_role.default[*].id)
}
# 默认不会创建这个 attach, 如果需要，需要设置 var.cache_type = "S3"
# 如果你设置了 var.cache_type = "S3"， 这个policy也是attach 到 default role中
resource "aws_iam_role_policy_attachment" "default_cache_bucket" {
  count      = module.this.enabled && local.s3_cache_enabled ? 1 : 0
  policy_arn = join("", aws_iam_policy.default_cache_bucket[*].arn)
  role       = join("", aws_iam_role.default[*].id)
}
# 用于管理 AWS CodeBuild 的源码凭证。该资源用于将第三方代码仓库（如 GitHub、GitHub Enterprise 或 Bitbucket）的访问凭证存储到 AWS 中，以便 CodeBuild 项目能够安全地访问私有仓库。
#核心作用
# 安全访问私有代码仓库：
#   使用 aws_codebuild_source_credential，您可以安全地为 CodeBuild 配置 GitHub、GitHub Enterprise 或 Bitbucket 的凭证，而无需直接在 source 块中暴露敏感信息。
# 集中管理源码凭证：
#   通过 AWS CodeBuild 支持的凭证机制，凭证会被安全加密并存储在 AWS。
# 与 CodeBuild 集成：
#   CodeBuild 使用此资源中定义的凭证来克隆私有代码仓库。
resource "aws_codebuild_source_credential" "authorization" {
  count       = module.this.enabled && var.private_repository ? 1 : 0
#  定义凭证的鉴权类型。PERSONAL_ACCESS_TOKEN：使用个人访问令牌（GitHub、GitHub Enterprise、Bitbucket）。
  auth_type   = var.source_credential_auth_type
#  指定源代码管理系统的类型。
#   GITHUB：适用于 GitHub 仓库。
#   GITHUB_ENTERPRISE：适用于 GitHub Enterprise 仓库。
#   BITBUCKET：适用于 Bitbucket 仓库。
  server_type = var.source_credential_server_type
#  存储用于访问源码管理系统的凭证（如 GitHub 的个人访问令牌）。
#  令牌必须具有访问目标代码仓库的权限。
#  建议将 token 存储在 Terraform 变量或 AWS Secrets Manager 中，而不是直接写在代码中。
  token       = var.source_credential_token
#  可选参数，仅适用于 GITHUB_ENTERPRISE 和 BITBUCKET
#  指定用户的用户名（如果需要）。
  user_name   = var.source_credential_user_name
}

# 将github 的 PAT 存储在secretsmanager 中
resource "aws_secretsmanager_secret" "github_token" {
  name = "github-token-${random_string.bucket_prefix[0].id}"
}
resource "aws_secretsmanager_secret_version" "github_token_version" {
  secret_id = aws_secretsmanager_secret.github_token.id
  secret_string = var.source_credential_token
}
#
resource "aws_codebuild_project" "default" {
  count                  = module.this.enabled ? 1 : 0
  name                   = module.this.id
  description            = var.description
  concurrent_build_limit = var.concurrent_build_limit
  service_role           = join("", aws_iam_role.default[*].arn)
  badge_enabled          = var.badge_enabled
  build_timeout          = var.build_timeout
  source_version         = var.source_version != "" ? var.source_version : null
  encryption_key         = var.encryption_key

  tags = {
    for name, value in module.this.tags :
    name => value
    if length(value) > 0
  }

#  artifacts 参数用于定义 构建任务生成的输出工件（artifacts）。它指定了构建的产物如何存储、存储的位置以及存储方式。
#  CodeBuild 支持将构建任务生成的工件存储到以下位置：
#      S3：存储到 Amazon S3 存储桶。
#      CodePipeline：通过 CodePipeline 管理构件。
#      NO_ARTIFACTS：不生成输出工件。
#  artifacts.type 必须设置为 CODEPIPELINE，以便 CodeBuild 的构建输出能够被传回 CodePipeline 的下一个阶段。
  artifacts {
    type     = var.artifact_type
    location = var.artifact_location
  }

  # Since the output type is restricted to S3 by the provider (this appears to
  # be an bug in AWS, rather than an architectural decision; see this issue for
  # discussion: https://github.com/hashicorp/terraform-provider-aws/pull/9652),
  # this cannot be a CodePipeline output. Otherwise, _all_ of the artifacts
  # would need to be secondary if there were more than one. For reference, see
  # https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html#action-reference-CodeBuild-config.
#  通过 dynamic 块，可以根据条件动态地添加次级工件配置。这里的次级工件存储类型被限制为 S3，并且专门处理如何将工件存储在 S3 的根目录。
#  当前 AWS 提供的 Terraform Provider 对 CodeBuild 的限制是主工件类型必须为 S3，所有次级工件类型也必须为 S3。
#  这是 AWS API 的实现问题，详情可以参考注释中的链接。
  dynamic "secondary_artifacts" {
    for_each = var.secondary_artifact_location != null ? [1] : []
    content {
      type                = "S3"
      location            = var.secondary_artifact_location
      artifact_identifier = var.secondary_artifact_identifier
      encryption_disabled = !var.secondary_artifact_encryption_enabled
      # According to AWS documention, in order to have the artifacts written
      # to the root of the bucket, the 'namespace_type' should be 'NONE'
      # (which is the default), 'name' should be '/', and 'path' should be
      # empty. For reference, see https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectArtifacts.html.
      # However, I was unable to get this to deploy to the root of the bucket
      # unless path was also set to '/'.
      path = "/"
      name = "/"
    }
  }

  cache {
    type     = lookup(local.cache, "type", null)
    location = lookup(local.cache, "location", null)
    modes    = lookup(local.cache, "modes", null)
  }

  environment {
#    (Required) Information about the compute resources the build project will use. Valid values: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE, BUILD_LAMBDA_1GB, BUILD_LAMBDA_2GB, BUILD_LAMBDA_4GB, BUILD_LAMBDA_8GB, BUILD_LAMBDA_10GB. BUILD_GENERAL1_SMALL is only valid if type is set to LINUX_CONTAINER. When type is set to LINUX_GPU_CONTAINER, compute_type must be BUILD_GENERAL1_LARGE. When type is set to LINUX_LAMBDA_CONTAINER or ARM_LAMBDA_CONTAINER, compute_type must be BUILD_LAMBDA_XGB.`
#    在 Terraform 的 aws_codebuild_project 中，compute_type 是 environment 块中的一个关键参数，用于定义 AWS CodeBuild 构建环境的计算资源规格。
#    其作用可以概括为：
#     1. 控制构建环境的计算能力（CPU 和内存）。
#     2. 为构建任务分配适当的资源，以确保构建过程顺利完成。
#     3.优化成本和性能，根据任务需求选择合适的规格，避免资源浪费或性能不足。
#    定义构建实例规格：
#     BUILD_GENERAL1_SMALL：小型实例。
#     BUILD_GENERAL1_MEDIUM：中型实例。
#     BUILD_GENERAL1_LARGE：大型实例。
#     BUILD_GENERAL1_2XLARGE：超大型实例。
    compute_type                = var.build_compute_type
#    image 参数用于指定 AWS CodeBuild 构建环境的 Docker 镜像。
#    这个镜像定义了 CodeBuild 项目运行时所需的构建环境，包括 操作系统、工具链、语言运行时 以及其他预装的软件。
#     CodeBuild 会基于这个镜像创建构建容器来执行 buildspec.yml 文件中的构建任务。
    image                       = var.build_image
#    参数 image_pull_credentials_type 定义拉取镜像时使用的权限
#    CODEBUILD：
#       使用 CodeBuild 默认的镜像拉取权限。
#       适用于公共镜像（如 AWS 托管镜像或 Docker Hub 镜像）。
#     SERVICE_ROLE：
#       使用 CodeBuild 项目的服务角色权限。
#       适用于需要授权的私有镜像（如 Amazon ECR 中的镜像）。
    image_pull_credentials_type = var.build_image_pull_credentials_type
#   type 参数用于指定 CodeBuild 使用的构建环境类型。这个参数定义了构建任务运行的容器类型，也决定了使用的操作系统（Linux 或 Windows）。
#    (Required) Type of build environment to use for related builds. Valid values: LINUX_CONTAINER, LINUX_GPU_CONTAINER, WINDOWS_CONTAINER (deprecated), WINDOWS_SERVER_2019_CONTAINER, ARM_CONTAINER, LINUX_LAMBDA_CONTAINER, ARM_LAMBDA_CONTAINER. For additional information, see the CodeBuild User Guide.
    type                        = var.build_type
#    (Optional) Whether to enable running the Docker daemon inside a Docker container. Defaults to false.
#    启用 特权模式 后，CodeBuild 容器会获得更高的权限，可以访问宿主机的一些功能和资源，例如 Docker 引擎
#    如果未设置 privileged_mode，CodeBuild 容器以普通模式运行，权限受限，无法运行 Docker 容器或访问宿主机功能。
#    以下场景中特别有用：
#   运行 Docker 构建任务：
#       构建 Docker 镜像（如 docker build）。
#       推送镜像到 Docker Registry（如 Amazon ECR）。
#   运行需要高权限的任务：
#       在容器中安装低级系统工具或服务。
#       使用内核功能（如挂载文件系统）。
    privileged_mode             = var.privileged_mode

#    codebuild 中的 environment 变量
    environment_variable {
      name  = "AWS_REGION"
      value = local.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = local.aws_account_id
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.image_repo_name)) == 1 ? [""] : []
      content {
        name  = "IMAGE_REPO_NAME"
        value = var.image_repo_name
      }
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.image_tag)) == 1 ? [""] : []
      content {
        name  = "IMAGE_TAG"
        value = var.image_tag
      }
    }

    dynamic "environment_variable" {
      for_each = signum(length(module.this.stage)) == 1 ? [""] : []
      content {
        name  = "STAGE"
        value = module.this.stage
      }
    }

    dynamic "environment_variable" {
      for_each = signum(length(var.github_token)) == 1 ? [""] : []
      content {
        name  = "GITHUB_TOKEN"
        value = var.github_token
        type  = "PLAINTEXT"
      }
    }

    dynamic "environment_variable" {
      for_each = var.environment_variables
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }

  }

  source {
    buildspec           = var.buildspec
#    (Required) Type of repository that contains the source code to be built. Valid values: BITBUCKET, CODECOMMIT, CODEPIPELINE, GITHUB, GITHUB_ENTERPRISE, GITLAB, GITLAB_SELF_MANAGED, NO_SOURCE, S3.
#    type 参数用于定义 CodeBuild 项目的代码来源类型（即构建任务的输入源）。通过 type 参数，您可以指定代码的来源，例如 S3、GitHub、AWS CodeCommit 或其他来源。
#    1. 当 CodeBuild 项目与 CodePipeline 集成时，source.type 必须设置为 CODEPIPELINE。
#    2. CodePipeline 将负责将输入（例如 GitHub 或 S3 中的代码）传递给 CodeBuild。
    type                = var.source_type
#    Location of the source code from git or s3.
#    在 source 块中，无需指定 location 或 buildspec，因为这些信息由 CodePipeline 提供。
    location            = var.source_location
    report_build_status = var.report_build_status
    git_clone_depth     = var.git_clone_depth != null ? var.git_clone_depth : null

    dynamic "git_submodules_config" {
      for_each = var.fetch_git_submodules ? [""] : []
      content {
        fetch_submodules = true
      }
    }
  }

  dynamic "secondary_sources" {
    for_each = var.secondary_sources
    content {
      git_clone_depth     = secondary_source.value.git_clone_depth
      location            = secondary_source.value.location
      source_identifier   = secondary_source.value.source_identifier
      type                = secondary_source.value.type
      insecure_ssl        = secondary_source.value.insecure_ssl
      report_build_status = secondary_source.value.report_build_status

      git_submodules_config {
        fetch_submodules = secondary_source.value.fetch_submodules
      }
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_config) > 0 ? [""] : []
    content {
      vpc_id             = lookup(var.vpc_config, "vpc_id", null)
      subnets            = lookup(var.vpc_config, "subnets", null)
      security_group_ids = lookup(var.vpc_config, "security_group_ids", null)
    }
  }

  dynamic "logs_config" {
    for_each = length(var.logs_config) > 0 ? [""] : []
    content {
      dynamic "cloudwatch_logs" {
        for_each = contains(keys(var.logs_config), "cloudwatch_logs") ? { key = var.logs_config["cloudwatch_logs"] } : {}
        content {
          status      = lookup(cloudwatch_logs.value, "status", null)
          group_name  = lookup(cloudwatch_logs.value, "group_name", null)
          stream_name = lookup(cloudwatch_logs.value, "stream_name", null)
        }
      }

      dynamic "s3_logs" {
        for_each = contains(keys(var.logs_config), "s3_logs") ? { key = var.logs_config["s3_logs"] } : {}
        content {
          status              = lookup(s3_logs.value, "status", null)
          location            = lookup(s3_logs.value, "location", null)
          encryption_disabled = lookup(s3_logs.value, "encryption_disabled", null)
        }
      }
    }
  }

  dynamic "file_system_locations" {
    for_each = length(var.file_system_locations) > 0 ? [""] : []
    content {
      identifier    = lookup(file_system_locations.value, "identifier", null)
      location      = lookup(file_system_locations.value, "location", null)
      mount_options = lookup(file_system_locations.value, "mount_options", null)
      mount_point   = lookup(file_system_locations.value, "mount_point", null)
      type          = lookup(file_system_locations.value, "type", null)
    }
  }
}


resource "aws_ssm_parameter" "github_token" {
  description = "The github token has stored"
  name  = "GITHUB_TOKEN"
  type  = "String"
  value = var.github_token
}