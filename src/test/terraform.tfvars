#task_exec_iam_statements = [
#  {
#    sid     = "AllowS3Access"
#    actions = ["s3:GetObject", "s3:ListBucket"]
#    effect  = "Allow"
#    resources = [
#      "arn:aws:s3:::example-bucket",
#      "arn:aws:s3:::example-bucket/*"
#    ]
#    conditions = [
#      {
#        test     = "StringEquals"
#        values   = ["example-value"]
#        variable = "aws:RequestedRegion"
#      }
#    ]
#  },
#  {
#    sid     = "DenyEC2Stop"
#    not_actions = ["ec2:StopInstances"]
#    effect  = "Deny"
#    resources = [
#      "arn:aws:ec2:*:123456789012:instance/*"
#    ]
#  }
#]

tasks_iam_role_name = "TaskRole"