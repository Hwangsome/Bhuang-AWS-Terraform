## task definition
## 这个变量不用去设置，
## task_definition_arn = ""
#
## Container definition(s)
#container_definitions = {
#
##  fluent-bit = {
##    cpu       = 512
##    memory    = 1024
##    essential = true
##    image     = nonsensitive(data.aws_ssm_parameter.fluentbit.value)
##    firelens_configuration = {
##      type = "fluentbit"
##    }
##    memory_reservation = 50
##    user               = "0"
##  }
#
#  (local.container_name) = {
#    cpu       = 512
#    memory    = 1024
#    essential = true
#    image     = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
#    port_mappings = [
#      {
#        name          = "go-simple-http-2"
#        containerPort = 80
#        hostPort      = 80
#        protocol      = "tcp"
#      }
#    ]
#
#    # Example image used requires access to write to root filesystem
#    readonly_root_filesystem = false
#
#    enable_cloudwatch_logging = false
#    log_configuration = {
#      logDriver = "awsfirelens"
#      options = {
#        Name                    = "firehose"
#        region                  = local.region
#        delivery_stream         = "my-stream"
#        log-driver-buffer-limit = "2097152"
#      }
#    }
#
#    linux_parameters = {
#      capabilities = {
#        add = []
#        drop = [
#          "NET_RAW"
#        ]
#      }
#    }
#
#    # Not required for fluent-bit, just an example
#    volumes_from = [{
#      sourceContainer = "fluent-bit"
#      readOnly        = false
#    }]
#
#    memory_reservation = 100
#  }
#}