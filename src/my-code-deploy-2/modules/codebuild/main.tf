data "aws_caller_identity" "default" {}

data "aws_region" "default" {}

resource "aws_s3_bucket" "cache_bucket" {
  #bridgecrew:skip=BC_AWS_S3_13:Skipping `Enable S3 Bucket Logging` check until bridgecrew will support dynamic blocks (https://github.com/bridgecrewio/checkov/issues/776).
  #bridgecrew:skip=BC_AWS_S3_14:Skipping `Ensure all data stored in the S3 bucket is securely encrypted at rest` check until bridgecrew will support dynamic blocks (https://github.com/bridgecrewio/checkov/issues/776).
  #bridgecrew:skip=CKV_AWS_52:Skipping `Ensure S3 bucket has MFA delete enabled` due to issue in terraform (https://github.com/hashicorp/terraform-provider-aws/issues/629).
  count         = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket        = local.cache_bucket_name_normalised
  force_destroy = true
  tags          = module.this.tags
}



resource "aws_s3_bucket_acl" "default" {
  count      = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket     = join("", resource.aws_s3_bucket.cache_bucket[*].id)
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)
  versioning_configuration {
    status = "Enabled"
  }
}

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

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket && var.access_log_bucket_name != "" ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  target_bucket = var.access_log_bucket_name
  target_prefix = "logs/${module.this.id}/"
}

resource "aws_s3_bucket_public_access_block" "default" {
  count  = module.this.enabled && local.create_s3_cache_bucket ? 1 : 0
  bucket = join("", resource.aws_s3_bucket.cache_bucket[*].id)

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "random_string" "bucket_prefix" {
  count   = module.this.enabled ? 1 : 0
  length  = 12
  numeric = false
  upper   = false
  special = false
  lower   = true
}

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

resource "aws_iam_role" "default" {
  count                 = module.this.enabled ? 1 : 0
  name                  = module.this.id
  assume_role_policy    = data.aws_iam_policy_document.role.json
  force_detach_policies = true
  path                  = var.iam_role_path
  permissions_boundary  = var.iam_permissions_boundary
  tags                  = module.this.tags
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

# 创建policy
resource "aws_iam_policy" "default" {
  count  = module.this.enabled ? 1 : 0
  name   = module.this.id
#  https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/reference_identifiers.html
  path   = var.iam_policy_path
  policy = data.aws_iam_policy_document.combined_permissions.json
  tags   = module.this.tags
}

resource "aws_iam_policy" "default_cache_bucket" {
  count = module.this.enabled && local.s3_cache_enabled ? 1 : 0

  name   = "${module.this.id}-cache-bucket"
  path   = var.iam_policy_path
  policy = join("", data.aws_iam_policy_document.permissions_cache_bucket[*].json)
  tags   = module.this.tags
}

data "aws_s3_bucket" "secondary_artifact" {
  count  = module.this.enabled ? (var.secondary_artifact_location != null ? 1 : 0) : 0
  bucket = var.secondary_artifact_location
}

# code build 的permission
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

#Generates an IAM policy document in JSON format for use with resources that expect policy documents such as aws_iam_policy.
data "aws_iam_policy_document" "combined_permissions" {
#  (Optional) - List of IAM policy documents that are merged together into the exported document. In merging, statements with non-blank sids will override statements with the same sid from earlier documents in the list. Statements with non-blank sids will also override statements with the same sid from source_policy_documents. Non-overriding statements will be added to the exported document.
#  override_policy_documents 是 aws_iam_policy_document 数据源的一个高级属性，允许你覆盖和合并多个 IAM 策略文档。这在构建复杂的 IAM 策略时非常有用，因为它允许你组合多个策略文档，将它们合并为一个最终的策略文档。使用 override_policy_documents 可以减少冗余，并提高 IAM 策略配置的灵活性。
  override_policy_documents = compact([
#    你自定义的policy
    join("", var.custom_policy),
#    codebuild 所需要的权限
    join("", data.aws_iam_policy_document.permissions[*].json),
#    如果你 输入的参数vpc_config 不为空，那么就会将vpc_permissions compact 到这个json 中
    var.vpc_config != {} ? join("", data.aws_iam_policy_document.vpc_permissions[*].json) : null
  ])
}

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

# 角色与策略的关联：aws_iam_role_policy_attachment 将 IAM 角色与 IAM 策略关联起来，使得该角色具备策略中定义的权限。例如，可以将 S3 访问策略附加到 EC2 实例角色上，使得该角色可以访问 S3 资源。
# 分离角色和策略：使用 aws_iam_role_policy_attachment 允许你独立地管理 IAM 角色和 IAM 策略，而不是将策略直接嵌入到角色中。这种做法更灵活，可以轻松更换策略或复用策略。
resource "aws_iam_role_policy_attachment" "default" {
  count      = module.this.enabled ? 1 : 0
#  (Required) - The ARN of the policy you want to apply
  policy_arn = join("", aws_iam_policy.default[*].arn)
#   The name of the IAM role to which the policy should be applied
  role       = join("", aws_iam_role.default[*].id)
}

resource "aws_iam_role_policy_attachment" "default_cache_bucket" {
  count      = module.this.enabled && local.s3_cache_enabled ? 1 : 0
  policy_arn = join("", aws_iam_policy.default_cache_bucket[*].arn)
  role       = join("", aws_iam_role.default[*].id)
}

resource "aws_codebuild_source_credential" "authorization" {
  count       = module.this.enabled && var.private_repository ? 1 : 0
  auth_type   = var.source_credential_auth_type
  server_type = var.source_credential_server_type
  token       = var.source_credential_token
  user_name   = var.source_credential_user_name
}

#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#environment-1
resource "aws_codebuild_project" "default" {
  count                  = module.this.enabled ? 1 : 0
#   (Required) Project's name.
  name                   = module.this.id
#  (Optional) Short description of the project.
  description            = var.description
#  (Optional) Specify a maximum number of concurrent builds for the project. The value specified must be greater than 0 and less than the account concurrent running builds limit.
  concurrent_build_limit = var.concurrent_build_limit
# (Required) Amazon Resource Name (ARN) of the AWS Identity and Access Management (IAM) role that enables AWS CodeBuild to interact with dependent AWS services on behalf of the AWS account.
#  指定 codebuild 的service role
  service_role           = join("", aws_iam_role.default[*].arn)
#  (Optional) Generates a publicly-accessible URL for the projects build badge. Available as badge_url attribute when enabled.
# 默认false
  badge_enabled          = var.badge_enabled
#  (Optional) Number of minutes, from 5 to 2160 (36 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed. The default is 60 minutes. The build_timeout property is not available on the Lambda compute type.
#  build 的超时时间
  build_timeout          = var.build_timeout
#  (Optional) Version of the build input to be built for this project. If not specified, the latest version is used.
#   a pull request, branch, commit ID, tag, or reference and a commit ID.
  source_version         = var.source_version != "" ? var.source_version : null
#  (Optional) AWS Key Management Service (AWS KMS) customer master key (CMK) to be used for encrypting the build project's build output artifacts.
  encryption_key         = var.encryption_key

  tags = {
    for name, value in module.this.tags :
    name => value
    if length(value) > 0
  }

  artifacts {
#    (Required) Build output artifact's type. Valid values: CODEPIPELINE, NO_ARTIFACTS, S3.
#    如果你选择的build 的artifacts 存储在s3上， 那么location 就是bucket的名字
    type     = var.artifact_type
#    (Optional) Information about the build output artifact location. If type is set to CODEPIPELINE or NO_ARTIFACTS, this value is ignored. If type is set to S3, this is the name of the output bucket.
    location = var.artifact_location

#    (Optional) Name of the project. If type is set to S3, this is the name of the output artifact object
#    s3 中的folder 的名字
    name = var.artifact_folder

#    (Optional) If type is set to S3, this is the path to the output artifact.
#    path = ""

#    (Optional) Type of build output artifact to create. If type is set to S3, valid values are NONE, ZIP
#    packaging = NONE

#    (Optional) Whether to disable encrypting output artifacts. If type is set to NO_ARTIFACTS, this value is ignored. Defaults to false.
#    encryption_disabled = false
#
  }

  # Since the output type is restricted to S3 by the provider (this appears to
  # be an bug in AWS, rather than an architectural decision; see this issue for
  # discussion: https://github.com/hashicorp/terraform-provider-aws/pull/9652),
  # this cannot be a CodePipeline output. Otherwise, _all_ of the artifacts
  # would need to be secondary if there were more than one. For reference, see
  # https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html#action-reference-CodeBuild-config.
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

#  Default is NO_CACHE
  cache {
#    (Optional) Type of storage that will be used for the AWS CodeBuild project cache. Valid values: NO_CACHE, LOCAL, S3. Defaults to NO_CACHE.
    type     = lookup(local.cache, "type", null)
#    (Required when cache type is S3) Location where the AWS CodeBuild project stores cached resources. For type S3, the value must be a valid S3 bucket name/prefix.
    location = lookup(local.cache, "location", null)
#    (Required when cache type is LOCAL) Specifies settings that AWS CodeBuild uses to store and reuse build dependencies. Valid values: LOCAL_SOURCE_CACHE, LOCAL_DOCKER_LAYER_CACHE, LOCAL_CUSTOM_CACHE.
    modes    = lookup(local.cache, "modes", null)
  }

  environment {
#    (Required) Information about the compute resources the build project will use. Valid values: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE, BUILD_LAMBDA_1GB, BUILD_LAMBDA_2GB, BUILD_LAMBDA_4GB, BUILD_LAMBDA_8GB, BUILD_LAMBDA_10GB. BUILD_GENERAL1_SMALL is only valid if type is set to LINUX_CONTAINER. When type is set to LINUX_GPU_CONTAINER, compute_type must be BUILD_GENERAL1_LARGE. When type is set to LINUX_LAMBDA_CONTAINER or ARM_LAMBDA_CONTAINER, compute_type must be BUILD_LAMBDA_XGB.`
    compute_type                = var.build_compute_type
#    (Required) Docker image to use for this build project. Valid values include Docker images provided by CodeBuild (e.g aws/codebuild/amazonlinux2-x86_64-standard:4.0), Docker Hub images (e.g., hashicorp/terraform:latest), and full Docker repository URIs such as those for ECR (e.g., 137112412989.dkr.ecr.us-west-2.amazonaws.com/amazonlinux:latest).
    image                       = var.build_image
#    (Optional) Type of credentials AWS CodeBuild uses to pull images in your build. Valid values: CODEBUILD, SERVICE_ROLE. When you use a cross-account or private registry image, you must use SERVICE_ROLE credentials. When you use an AWS CodeBuild curated image, you must use CodeBuild credentials. Defaults to CODEBUILD.
    image_pull_credentials_type = var.build_image_pull_credentials_type
#    (Required) Type of build environment to use for related builds. Valid values: LINUX_CONTAINER, LINUX_GPU_CONTAINER, WINDOWS_CONTAINER (deprecated), WINDOWS_SERVER_2019_CONTAINER, ARM_CONTAINER, LINUX_LAMBDA_CONTAINER, ARM_LAMBDA_CONTAINER. For additional information, see the CodeBuild User Guide.(https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html)
    type                        = var.build_type
#    (Optional) Whether to enable running the Docker daemon inside a Docker container. Defaults to false.
    privileged_mode             = var.privileged_mode

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
        type  = var.github_token_type
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

#  配置source
  source {
    #  (Optional) Build specification to use for this build project's related builds. This must be set when type is NO_SOURCE. Also, if a non-default buildspec file name or file path aside from the root is used, it must be specified.
#    buildspec 的作用：它是 CodeBuild 的核心配置，用于定义构建过程的步骤、构建环境变量以及构件的输出等。
#    显式指定的场景：
#    当 buildspec.yml 不在代码仓库的根目录。
#    希望动态生成或传递自定义的 buildspec。
#    使用 NO_SOURCE 或从 CodePipeline 提供输入，但没有代码仓库中的 buildspec.yml。
    buildspec           = var.buildspec
#    (Required) Type of repository that contains the source code to be built. Valid values: BITBUCKET, CODECOMMIT, CODEPIPELINE, GITHUB, GITHUB_ENTERPRISE, GITLAB, GITLAB_SELF_MANAGED, NO_SOURCE, S3.
#    指定你从哪里build 代码
#  1. type
#  说明：指定源码的类型。
#   可选值：
#     GITHUB：从 GitHub 仓库拉取代码。
#     CODECOMMIT：从 AWS CodeCommit 仓库拉取代码。
#     BITBUCKET：从 Bitbucket 仓库拉取代码。
#     S3：从 AWS S3 存储桶拉取代码包。
#     NO_SOURCE：没有源码，构建不依赖源码（通常用在自定义构建环境中）。
#    在 aws_codebuild_project 的 source 配置中，type 也可以设置为 CODEPIPELINE，表示该 CodeBuild 项目将作为 AWS CodePipeline 流水线的一部分运行构建任务。
#    当 type = "CODEPIPELINE" 时，CodeBuild 的输入代码来源由 CodePipeline 提供，因此不需要显式定义代码的 location，也不能指定 buildspec 等参数。
    type                = var.source_type
#    (Optional) Location of the source code from git or s3.
    location            = var.source_location
#    (Optional) Whether to report the status of a build's start and finish to your source provider. This option is valid only when your source provider is GitHub, GitHub Enterprise, GitLab, GitLab Self Managed, or Bitbucket.
#    default is false
    report_build_status = var.report_build_status
#    (Optional) Truncate git history to this many commits. Use 0 for a Full checkout which you need to run commands like git branch --show-current. See AWS CodePipeline User Guide: Tutorial: Use full clone with a GitHub pipeline source for details(https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-github-gitclone.html)
    git_clone_depth     = var.git_clone_depth != null ? var.git_clone_depth : null

    dynamic "git_submodules_config" {
      for_each = var.fetch_git_submodules ? [""] : []
      content {
#        (Required) Whether to fetch Git submodules for the AWS CodeBuild build project.
        fetch_submodules = true
      }
    }
  }

#  This block is only valid when the type is CODECOMMIT, GITHUB, GITHUB_ENTERPRISE, GITLAB, or GITLAB_SELF_MANAGED.
#  默认不创建，如果你需要创建，你需要传  secondary_sources 参数
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
#        (Required) Whether to fetch Git submodules for the AWS CodeBuild build project.
        fetch_submodules = secondary_source.value.fetch_submodules
      }
    }
  }

#  这个在codebuild ui 配置中的 Additional configuration
  dynamic "vpc_config" {
    for_each = length(var.vpc_config) > 0 ? [""] : []
    content {
#      (Required) Security group IDs to assign to running builds.
      vpc_id             = lookup(var.vpc_config, "vpc_id", null)
#      (Required) Subnet IDs within which to run builds.
      subnets            = lookup(var.vpc_config, "subnets", null)
#      (Required) ID of the VPC within which to run builds.
      security_group_ids = lookup(var.vpc_config, "security_group_ids", null)
    }
  }

#  配置codebuild 的时候 的log 可以在cloud watch 中查看
  dynamic "logs_config" {
    for_each = length(var.logs_config) > 0 ? [""] : []
    content {
      dynamic "cloudwatch_logs" {
        for_each = contains(keys(var.logs_config), "cloudwatch_logs") ? { key = var.logs_config["cloudwatch_logs"] } : {}
        content {
#          (Optional) Current status of logs in CloudWatch Logs for a build project. Valid values: ENABLED, DISABLED. Defaults to ENABLED
          status      = lookup(cloudwatch_logs.value, "status", null)
#           (Optional) Group name of the logs in CloudWatch Logs.
          group_name  = lookup(cloudwatch_logs.value, "group_name", null)
#           (Optional) Prefix of the log stream name of the logs in CloudWatch Logs.
          stream_name = lookup(cloudwatch_logs.value, "stream_name", null)
        }
      }

#      this option will upload build output logs to S3.
#      你可以开启将 codebuild 的logs 文件存储在s3 中
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

#  (Optional) A set of file system locations to mount inside the build. File system locations are documented below.
#  这个配置在Additional configuration UI 中可以看到
  dynamic "file_system_locations" {
    for_each = length(var.file_system_locations) > 0 ? [""] : []
    content {
#      (Optional) The name used to access a file system created by Amazon EFS. CodeBuild creates an environment variable by appending the identifier in all capital letters to CODEBUILD_. For example, if you specify my-efs for identifier, a new environment variable is create named CODEBUILD_MY-EFS.
      identifier    = lookup(file_system_locations.value, "identifier", null)
#      (Optional) A string that specifies the location of the file system created by Amazon EFS. Its format is efs-dns-name:/directory-path.
      location      = lookup(file_system_locations.value, "location", null)
#      (Optional) The mount options for a file system created by AWS EFS.
      mount_options = lookup(file_system_locations.value, "mount_options", null)
#      (Optional) The location in the container where you mount the file system.
      mount_point   = lookup(file_system_locations.value, "mount_point", null)
#      (Optional) The type of the file system. The one supported type is EFS.
      type          = lookup(file_system_locations.value, "type", null)
    }
  }
}
