terraform {
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.1"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 1.2"
    }
  }
}
