terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "capstone-tf-state-d2e99694"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "capstone-tf-lock"
    encrypt        = true
  }
}

provider "aws" { region = "us-east-1" }
