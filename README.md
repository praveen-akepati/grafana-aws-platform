# Grafana AWS Platform

Highly available Grafana on AWS: **Terraform** (infrastructure), **Packer** (golden AMI), **Ansible** (runtime configuration).

Based on the solution design: ALB + ASG (2–5 nodes) + RDS PostgreSQL Multi-AZ, private subnets, Secrets Manager, Route 53, ACM.

## Repository layout

| Path | Purpose |
|------|---------|
| `terraform/environments/prod` | Root stack for production |
| `terraform/modules/*` | VPC, ALB, ASG, RDS, DNS, secrets, logging, monitoring, VPN stub |
| `packer/` | Build Grafana base AMI (Ansible + dashboard tree on image) |
| `ansible/` | Configure DB, admin, Prometheus datasource, dashboard sync |
| `grafana/dashboards/` | **Git source of truth** for dashboard JSON (`client-imported/`, `our-ops/`) |
| `docs/` | Architecture, runbook, Windows tools, Packer (WSL), local Prometheus (POC), [dual Grafana model](docs/dual-grafana-model.md), [dashboard GitOps](docs/grafana-gitops.md), client Prometheus (K8s) |

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- Packer >= 1.9 (build AMI from WSL — see `docs/packer-build-wsl.md`)
- Ansible collections in **WSL** (optional manual playbooks; EC2 bootstrap uses Ansible on the instance)

See `docs/setup-windows-tools.md` and `docs/local-prometheus-before-aws.md` for POC. For production client Prometheus on Kubernetes, see **`docs/client-prometheus-kubernetes.md`**.

## Deploy order

### 0. Local Prometheus + ngrok (POC)

See `docs/local-prometheus-before-aws.md`. Confirm tunnel with `ngrok-skip-browser-warning` header if using ngrok free tier.

### 1. Bootstrap remote state (once per org)

See `terraform/backend.tf.example` for S3 + DynamoDB setup.

### 2. Build AMI (WSL)

See `docs/packer-build-wsl.md`.

```bash
cd /path/to/grafana-aws-platform/packer
packer init grafana.pkr.hcl
packer build -var region=ap-south-1 grafana.pkr.hcl
```

Note the output AMI ID.

### 3. Configure Terraform

```bash
cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
# Edit grafana_ami_id and allowed_ingress_cidrs (your public IP /32)
# POC default: use_custom_domain = false (no domain or Route 53 required)
```

### 4. Apply infrastructure

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

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

- S3 logging bucket (ALB access logs, VPC flow logs)
- CloudWatch alarms (ALB 5xx, unhealthy targets, RDS CPU)
- RDS encryption, Multi-AZ, backup retention
- IMDSv2 required on EC2
- Secrets Manager for credentials
- ASG CPU target tracking (min 2 / max 5)
- User data runs Ansible from AMI on scale-out

For **work production**, set `poc_mode = false` in `terraform.tfvars` before apply (enables RDS deletion protection, final snapshot, backups, and secret recovery window).

## Grafana dashboards (Git)

Dashboard JSON lives in **`grafana/dashboards/`** — same repo, separate folder from Terraform/Ansible:

- **`client-imported/`** — adapt the client's existing dashboards (clusters, apps) as a starting point
- **`our-ops/`** — dashboards your team adds

See **`docs/grafana-gitops.md`** for import steps, datasource retargeting, and deploy workflow.

## Tear down (POC)

With `poc_mode = true`, `terraform destroy` in `terraform/environments/prod` removes the stack without leaving RDS snapshots or a protected database. See `docs/runbook.md`.

## Client engagement (metrics already at client)

If the client **already has Prometheus and dashboards** but wants **your company** to run **your own Grafana** for your operations, start with **`docs/dual-grafana-model.md`**, then **`docs/client-prometheus-kubernetes.md`** for VPN and connectivity.

## Client open items

Before go-live, confirm with the client:

- Prometheus connectivity — **`docs/client-prometheus-kubernetes.md`** (VPN, HTTPS allowlist, client K8s Ingress)
- DNS ownership and domain
- Authentication (LDAP/SSO — extend Ansible role)
- SNS email for alarms (`sns_topic_email` in monitoring module)

## License

Internal / your organization — adjust as needed.
