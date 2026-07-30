# Architecture

## Traffic flow

```
Users ΓåÆ Route 53 ΓåÆ ALB (HTTPS:443) ΓåÆ Grafana EC2 (:3000) ΓåÆ RDS PostgreSQL
                                              Γåô
                         Client Prometheus (K8s, client network ΓÇö VPN or HTTPS)
```

Grafana runs in **your** AWS VPC. Client Prometheus runs in **their** Kubernetes / corporate network. For the common case where the client keeps their own Grafana and you host yours for your ops, see **`docs/dual-grafana-model.md`**. For connectivity, see **`docs/client-prometheus-kubernetes.md`**.

## Tooling responsibilities

| Component | Tool |
|-----------|------|
| VPC, subnets, NAT | Terraform |
| ALB, ACM, Route 53 | Terraform |
| EC2 instances (Grafana nodes), ASG, launch template, IAM | Terraform |
| RDS PostgreSQL Multi-AZ | Terraform |
| Secrets Manager | Terraform |
| CloudWatch alarms, S3 logs | Terraform |
| Site-to-site VPN (optional, client Prometheus) | Terraform (`enable_client_vpn`) |
| Golden AMI (Ubuntu, Grafana package, CloudWatch agent, Ansible + dashboard tree) | Packer |
| EC2 bootstrap: DB config, datasource, admin, dashboard sync | Ansible (user_data at launch; optional manual re-run) |
| Dashboard JSON (Git) | `grafana/dashboards/` ΓåÆ Ansible file provisioning |

## HA notes

- **EC2:** two or more Grafana nodes in private subnets, managed by the ASG (min 2 / max 5).
- Grafana session and config state live in PostgreSQL (required for multiple nodes).
- ALB health checks use `/api/health` on port 3000 on each EC2 instance.
- New EC2 instances bootstrap via launch template user data + Ansible playbook on the AMI.

## Client connectivity outputs

After `terraform apply`, share with the client when setting up VPN or firewall rules:

```bash
terraform output vpc_cidr
terraform output nat_gateway_public_ip   # HTTPS IP allowlist only ΓÇö prefer VPN + CIDR
```

## Optional VPN add-on

Set `enable_client_vpn = true` in `terraform.tfvars` (see `terraform.tfvars.example`). Uses `terraform/modules/vpn`. See **`docs/client-prometheus-kubernetes.md`** and **`docs/deploy-guide.md`**.
