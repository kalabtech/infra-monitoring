terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key = "infra-monitoring/prod/network/terraform.tfstate"
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = lower(var.project_name)
      Environment = lower(var.environment)
      ManagedBy   = lower(var.managedby)
    }
  }
}
