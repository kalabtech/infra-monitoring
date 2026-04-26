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

variable "aws_region" {
  description = "AWS Region for provider"
  type        = string
}
