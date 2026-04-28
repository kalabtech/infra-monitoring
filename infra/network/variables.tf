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

# VPC Vars
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az" {
  description = "Availability zones"
  type        = string
  default     = "eu-west-1a"
}

variable "public_subnet_cidr" {
  description = "CIDR blocks for public subnets"
  type        = string
  default     = "10.0.1.0/24"
}
