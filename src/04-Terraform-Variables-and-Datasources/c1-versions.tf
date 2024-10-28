terraform {
  required_version = ">= 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  # 指定 AWS 区域 , 通过 region 参数，你可以控制 Terraform 在哪个区域操作资源。
  #  在该配置下，所有与 AWS 相关的 API 调用和资源操作（例如创建 EC2 实例、S3 存储桶、RDS 实例等）都会限定在 us-west-2 区域。
  region  = var.aws_region
  # 使用本地 AWS CLI 配置的凭证文件
  profile = "default"
}

# Resource: EC2 Instance
#resource "aws_instance" "terraform-ec2-04" {
#  ami = "ami-0533f2ba8a1995cf9"
#  instance_type = var.instance_type
#  user_data = file("${path.module}/app1-install.sh")
#  tags = {
#    "Name" = "EC2 Demo"
#  }
#}