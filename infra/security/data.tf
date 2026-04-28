# security/data.tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.project_name}/${var.environment}/network/terraform.tfstate"
    region = var.aws_region
  }
}

# url-shortener remote state
# NOTE: hardcoded project name
data "terraform_remote_state" "url_shortener" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "url-shortener-demo/${var.environment}/network/terraform.tfstate"
    region = var.aws_region
  }
}
