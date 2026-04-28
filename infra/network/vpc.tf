# TODO: enable VPC Flow Logs
#trivy:ignore:AVD-AWS-0178 - VPC does not have VPC Flow Logs enabled.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  region               = var.aws_region
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = lower("${var.project_name}-vpc")
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.az

  tags = {
    Name = lower("${var.project_name}-public-${var.az}")
  }
}
