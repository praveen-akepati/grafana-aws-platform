# Grafana AWS Platform

Highly available Grafana on AWS: **Terraform** (infrastructure), **Packer** (golden AMI), **Ansible** (runtime configuration).

Based on the solution design: ALB + ASG (2–5 nodes) + RDS PostgreSQL Multi-AZ, private subnets, Secrets Manager, Route 53, ACM.

## Repository layout

| Path | Purpose |
|------|---------|
| `terraform/environments/prod` | Root stack for production |
| `terraform/modules/*` | VPC, ALB, ASG, RDS, DNS, secrets, logging, monitoring, VPN stub |
| `packer/` | Build Grafana base AMI (Ansible copied to image; configured at launch) |
| `ansible/` | Configure DB, admin, Prometheus datasource |
| `docs/` | Architecture, runbook, Windows tools, Packer (WSL), Grafana users, [dual Grafana model](docs/dual-grafana-model.md), client Prometheus (K8s) |

## Prerequisites

See **`docs/setup-windows-tools.md`** for Windows + WSL install and AWS profile setup.

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- Packer >= 1.9 (build AMI from WSL — see `docs/packer-build-wsl.md`)
- WSL 2 + Ubuntu (Packer builds; optional Ansible for manual playbooks)
- Route 53 hosted zone and domain when `use_custom_domain = true` (default)
- Client Prometheus URL **optional** — set `prometheus_url` when the client endpoint is reachable from your VPC; see **`docs/client-prometheus-kubernetes.md`**

## Deploy order

### 1. Bootstrap remote state (once per org)

See `terraform/backend.tf.example` for S3 + DynamoDB setup.

### 2. Build AMI

See `docs/packer-build-wsl.md`.

```bash
cd packer
packer init grafana.pkr.hcl
packer build -var region=ap-south-1
```

Note the output AMI ID.

### 3. Configure Terraform

```bash
cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
# Edit domain_name, hosted_zone_id, grafana_ami_id, allowed_ingress_cidrs
# Optional: prometheus_url when client metrics are reachable from AWS
# Set poc_mode = false for real production
```

Optional: `use_custom_domain = false` uses the ALB DNS name over HTTP (no Route 53).

### 4. Apply infrastructure

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

Open `terraform output grafana_url` after apply. Log in with the admin user from Secrets Manager — see **`docs/grafana-users.md`**.

### 5. Configure Grafana (optional if user_data succeeded)

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/configure-grafana.yml -i inventory/aws_ec2.yml \
  -e grafana_secrets_arn=<from terraform output> \
  -e aws_region=ap-south-1 \
  -e grafana_root_url=https://grafana.example.com \
  -e prometheus_url=https://prometheus.client.example.com
```

## Production enhancements included

- S3 logging bucket (ALB access logs, VPC flow logs) with delivery policies
- CloudWatch alarms (ALB 5xx, unhealthy targets, RDS CPU)
- RDS encryption, Multi-AZ, backup retention (when `poc_mode = false`)
- Terraform **destroy guard** (`terraform_data.destroy_guard`) when `poc_mode = false`
- IMDSv2 required on EC2
- Secrets Manager for credentials
- ASG CPU target tracking (min 2 / max 5)
- User data runs Ansible from AMI on scale-out (including Galaxy collections)

Set `poc_mode = false` in `terraform.tfvars` before a real production apply (RDS deletion protection, final snapshot, backups, secret recovery window, Terraform destroy guardrails). See `docs/runbook.md` for intentional production teardown.

## Grafana users

See **`docs/grafana-users.md`** — bootstrap admin from Secrets Manager, UI invites, API, and optional LDAP/OAuth.

## Tear down (sandbox)

With `poc_mode = true`, `terraform destroy` in `terraform/environments/prod` removes the stack without leaving RDS snapshots or a protected database. See `docs/runbook.md`.

## Client engagement (metrics already at client)

If the client **already has Prometheus and dashboards** but wants **your company** to run **your own Grafana** for your operations, start with **`docs/dual-grafana-model.md`**, then **`docs/client-prometheus-kubernetes.md`** for VPN and connectivity.

## Client open items

Before go-live, confirm with the client:

- Prometheus connectivity — **`docs/client-prometheus-kubernetes.md`** (VPN, HTTPS allowlist, client K8s Ingress)
- DNS ownership and domain
- Grafana users and SSO (`docs/grafana-users.md` — LDAP/OAuth extension)
- SNS email for alarms (`sns_topic_email` in monitoring module)

## License

Internal / your organization — adjust as needed.
