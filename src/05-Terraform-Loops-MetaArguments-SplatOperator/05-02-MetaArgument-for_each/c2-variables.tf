# Input Variables
# AWS Region
variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "us-west-2"
}

# AWS EC2 Instance Type
variable "instance_type" {
  description = "EC2 Instnace Type"
  type        = string
  default     = "t3.micro"
}

# AWS EC2 Instance Key Pair
variable "instance_keypair" {
  description = "AWS EC2 Key Pair that need to be associated with EC2 Instance"
  type        = string
  default     = "terraform-key"
}

# AWS EC2 Instance Type - List
variable "instance_type_list" {
  description = "EC2 Instance Type"
  type        = list(string)
  default     = ["t3.micro", "t3.small", "t3.large"]
}

# AWS EC2 Instance Type - Map
variable "instance_type_map" {
  description = "EC2 Instance Type"
  type        = map(string)
  default     = {
    "dev"  = "t3.micro"
    "qa"   = "t3.small"
    "prod" = "t3.large"
  }
}

variable "server_statuses" {
  type    = map(string)
  default = {
    server1 = "running"
    server2 = "stopped"
    server3 = "running"
  }
}

variable "users" {
  type = map(object({
    role = string
  }))

  #  在这个例子中，users 是一个 map，默认值 包含两个键 "user1" 和 "user2"，每个键的值是一个对象。
  # Example of providing values
  default = {
    "user1" = {
      role = "admin"
    },
    "user2" = {
      role = "developer"
    }
  }
}

locals {
/**
local_test                          = {
       admin     = "user1"
       developer = "user2"
    }
name is key and user is value
**/
  users_by_role = {
    for name, user in var.users : user.role => name
  }
}


