# ADR-002: Network placement for monitoring infrastructure

## Status

Accepted

## Date

2026-04-29

## Context

 This project deploys a monitoring stack (Prometheus + Grafana) on a single EC2 instance. The monitoring stack need network access to application instances running in other project VPCs to scrape metrics. We need to decide whether monitoring lives inside each project's VPC or in its own dedicated VPC.

 We operate in a single AWS account on free tier. Keeping resource count and cost low is a priority without sacrificing basic security.

## Decision

 Use a dedicated VPC for the monitoring stack, connected to project VPCs via VPC Peering

## Positive Consequences

- Monitoring stack is isolated from project infrastructure. A misconfiguration in monitoring doesn't affect application networking or security groups.
- Each project VPC stays clean, no monitoring resources mixed in.
- Peering connections are free for data transfer within the same AZ, and the connection itself has no hourly cost.
- Easy to tear down monitoring without touching project infrastructure.

## Negative Consequences

- Peering doesn't scale well. Each new project VPC needs a new peering connection, and peering is not transitive (A-B and A-C doesn't mean B-C). With 4-5 projects it gets harder to maintain.
- Extra VPC means extra Terraform code to maintain (subnets, route tables, NACLs, security groups).
- Cross-AZ data transfer between peered VPCs does have cost ($0.01/GB). Small in this case but worth noting.
- CIDR blocks must not overlap between peered VPCs. Address ranges need upfront planning or peering will fail.

## Alternatives Considered

### Shared VPC:
 Place monitoring resources directly in the same VPC as the project being monitored. No cross-VPC connectivity needed.

 Discarded because it couples monitoring lifecycle to each project. Destroying a project's infrastructure takes monitoring down with it. It also means duplicating monitoring resources if you want to monitor multiple projects, and project VPCs accumulate security groups and subnets that don't belong to them. No network isolation between concerns.

### Transit Gateway:
 Create a central hub that connects all VPCs through a single gateway. Monitoring VPC connects once to the TGW, and every project VPC does the same. Connectivity is transitive, so adding a new project is just one more attachment.

 Discarded because of cost. TGW charges ~$36/month just for the attachment plus $0.02/GB of data processed. For a portfolio project on free tier with 2-3 VPCs, it's overkill.
 **This would be the right choice in production with many VPCs**.

### Site-to-site VPN:
 Establish an encrypted VPN tunnel between VPCs.

 Discarded because it solves a different problem. VPN is designed for connecting on-premise networks to AWS, not VPC-to-VPC communication within the same account. Adds unnecessary complexity and cost (~$36/month per connection) with no benefit over peering in this scenario.
