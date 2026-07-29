# Architecture

## Traffic flow

```
Users → Route 53 → ALB (HTTPS:443) → Grafana EC2 (:3000) → RDS PostgreSQL
                                              ↓
                                    Client Prometheus (VPN or HTTPS)
```

## Tooling responsibilities

| Component | Tool |
|-----------|------|
| VPC, subnets, NAT | Terraform |
| ALB, ACM, Route 53 | Terraform |
| ASG, launch template, IAM | Terraform |
| RDS PostgreSQL Multi-AZ | Terraform |
| Secrets Manager | Terraform |
| CloudWatch alarms, S3 logs | Terraform |
| Grafana package + CloudWatch agent | Packer |
| DB config, datasource, admin | Ansible |

## HA notes

- Grafana session and config state live in PostgreSQL (required for multiple nodes).
- ALB health checks use `/api/health` on port 3000.
- New ASG instances bootstrap via user data + Ansible playbook on the AMI.

## Optional VPN add-on

Uncomment `module "vpn"` in `terraform/environments/prod/main.tf` and set customer gateway IP and CIDR when the client selects site-to-site VPN.
