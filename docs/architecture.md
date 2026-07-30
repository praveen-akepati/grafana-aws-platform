# Architecture

## Traffic flow

```
Users → Route 53 → ALB (HTTPS:443) → Grafana EC2 (:3000) → RDS PostgreSQL
                                              ↓
                         Client Prometheus (K8s, client network — VPN or HTTPS)
```

Grafana runs in **your** AWS VPC. Client Prometheus runs in **their** Kubernetes / corporate network. For the common case where the client keeps their own Grafana and you host yours for your ops, see **`docs/dual-grafana-model.md`**. For connectivity, see **`docs/client-prometheus-kubernetes.md`**.

## Tooling responsibilities

| Component | Tool |
|-----------|------|
| VPC, subnets, NAT | Terraform |
| ALB, ACM, Route 53 | Terraform |
| ASG, launch template, IAM | Terraform |
| RDS PostgreSQL Multi-AZ | Terraform |
| Secrets Manager | Terraform |
| CloudWatch alarms, S3 logs | Terraform |
| Grafana package + CloudWatch agent | Packer (shell install; Ansible on EC2 at launch) |
| DB config, datasource, admin | Ansible |

## HA notes

- Grafana session and config state live in PostgreSQL (required for multiple nodes).
- ALB health checks use `/api/health` on port 3000.
- New ASG instances bootstrap via user data + Ansible playbook on the AMI.

## Optional VPN add-on

For private access to client Prometheus (recommended when metrics stay off the public internet), enable `module "vpn"` in `terraform/environments/prod/main.tf` using `terraform/modules/vpn`. See **`docs/client-prometheus-kubernetes.md`**.
