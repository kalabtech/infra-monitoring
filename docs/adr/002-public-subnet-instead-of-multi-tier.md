# ADR-002: Use Public Subnet vs Private Subnet + NAT Gateway

## Status

Accepted

## Date

2026-04-29

## Context

 This project requires a single EC2 instance to run the monitoring stack. It doesn't need to be accessible from the internet, but it needs outbound traffic to download Docker images and system updates

 A multi-tier VPC with private subnets is the security standard for workloads that don't serve public traffic. However, placing the instance in a private subnet requires a NAT Gateway (~$32/month + $0.045/GB processed) and three VPC Endpoints for SSM (see ADR-003) access: ssm, ssmmessages, ec2messages at ~$7/month each (~$21/month total).

 We operate in a single AWS account on free tier. Keeping resource count and cost low is a priority without sacrificing basic security.



## Decision

Deploy the EC2 instance in a single public subnet with outbound internet access through an Internet Gateway. All inbound traffic is blocked via Security Groups. Instance access is managed exclusively through SSM Session Manager.

## Positive Consequences

- Zero additional cost. No NAT Gateway, no VPC Endpoints, no extra infrastructure. Saves ~$53/month compared to the private subnet approach.
- Fewer resources to manage and maintain: no NAT Gateway, no VPC Endpoints, no extra route tables.
- SSM Session Manager provides secure shell access without opening port 22. All sessions are logged and auditable through CloudWatch.
- No SSH keys to manage or rotate.

## Negative Consequences

- The instance has a public IP. Even with security groups blocking all inbound traffic, the instance is exposed at the network level. A security group misconfiguration would directly expose the instance to the internet.
- Does not follow the standard security practice of placing non-public workloads in private subnets. In a real production environment this would not pass a security review.
- Security relies on a single layer (security groups). In a private subnet you have defense in depth: no public IP + security groups + NACLs, so one misconfiguration alone doesn't expose the instance.

## Alternatives Considered

### Private subnet + NAT Gateway:
 Place the instance in a private subnet with outbound internet access through a NAT Gateway. The instance has no public IP and is not reachable from the internet.

 Discarded because of operational cost. NAT Gateway (~$32/month + data processing fees) plus three VPC Endpoints for SSM (~$21/month). This adds ~$53/month in baseline cost for this project.

### Private subnet + NAT Instance:
 Place the instance in a private subnet and deploy a separate EC2 instance in a public subnet to act as NAT, instead of using the AWS managed NAT Gateway. A t2.micro would be sufficient for this workload and is included in free tier.

 Discarded because of added complexity. The NAT Instance is self-managed: patching, no built-in high availability, and limited throughput. It adds a second EC2 instance to maintain just to avoid the cost of NAT Gateway.
