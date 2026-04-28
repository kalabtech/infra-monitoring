# Global Vars
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
  default = "prod"
}

variable "managedby" {
  description = "AWS provider tag managedby"
  type        = string
}

variable "aws_region" {
  description = "AWS Region for provider"
  type        = string
}

# Remote state vars
variable "state_bucket" {
  description = "AWS S3 remote state bucket"
  type        = string
}
