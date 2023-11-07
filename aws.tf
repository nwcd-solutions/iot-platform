terraform {
  required_version = "> 1.5.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #  Fix version version of the AWS provider
      version = "> 5.12.0"
    }
  }
}

provider "aws" {
  region                   = var.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
}


