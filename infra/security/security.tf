# NOTE: Default sg
resource "aws_default_security_group" "default" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # NOTE: No ingress or egress rules - locked down
  tags = {
    Name = lower("${var.project_name}-default-sg")
  }
}

# NOTE: App security group
resource "aws_security_group" "public" {
  name        = "public-sg"
  description = "Allow web all outbound traffic and monitoring ports"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = lower("${var.project_name}-public-sg")
  }
}

# NOTE: ec2 needs access to Docker Hub and update packages
# ?? trivy:ignore:AVD-AWS-0104 - Security group rule allows  egress to any IP address.
resource "aws_vpc_security_group_egress_rule" "allow_https" {
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# NOTE: app port
resource "aws_vpc_security_group_egress_rule" "app_scrape" {
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = data.terraform_remote_state.url_shortener.outputs.vpc_cidr
  from_port         = 5000
  ip_protocol       = "tcp"
  to_port           = 5000
}

# NOTE: prometheus node_exporter port
resource "aws_vpc_security_group_egress_rule" "node_exporter_scrape" {
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = data.terraform_remote_state.url_shortener.outputs.vpc_cidr
  from_port         = 9100
  ip_protocol       = "tcp"
  to_port           = 9100
}
