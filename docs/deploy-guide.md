# Production deploy guide

End-to-end checklist for hosting **your** Grafana on AWS while querying **client** Prometheus on Kubernetes. For deeper detail, follow the linked docs.

## Before you start

| Requirement | Doc |
|-------------|-----|
| Windows + WSL tools | `docs/setup-windows-tools.md` |
| Why two Grafanas | `docs/dual-grafana-model.md` |
| Client Prometheus connectivity | `docs/client-prometheus-kubernetes.md` |
| Dashboard Git workflow | `docs/grafana-gitops.md` |

**From the client (before go-live):**

- [ ] Prometheus base URL reachable from your VPC (or agree VPN)
- [ ] Your **VPC CIDR** allowed on their firewall (preferred over single IP)
- [ ] Auth for Prometheus API if required (token / basic / mTLS)
- [ ] Dashboard JSON exports (optional starting point) for `grafana/dashboards/client-imported/`

## Step 1 — Remote state (recommended)

One-time: create S3 + DynamoDB per `terraform/backend.tf.example`, then:

```bash
cd terraform/environments/prod
terraform init -migrate-state
```

## Step 2 — Build AMI (WSL)

```bash
cd packer
packer init grafana.pkr.hcl
packer build -var region=ap-south-1
```

See `docs/packer-build-wsl.md`. Note the **AMI ID**.

## Step 3 — Configure Terraform

```bash
cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
```

Edit `terraform.tfvars`:

| Variable | Production |
|----------|------------|
| `use_custom_domain` | `true` |
| `domain_name`, `hosted_zone_id` | Your Grafana URL |
| `grafana_ami_id` | From Packer |
| `allowed_ingress_cidrs` | Your office/VPN IPs |
| `prometheus_url` | Client URL when connectivity is ready |
| `poc_mode` | **`false`** |
| `enable_client_vpn` | `true` when VPN agreed (see below) |

## Step 4 — Client VPN (recommended)

In `terraform.tfvars`:

```hcl
enable_client_vpn       = true
customer_gateway_ip     = "CLIENT_VPN_PUBLIC_IP"
customer_network_cidr   = "172.16.0.0/12"   # client network / K8s reachable range
```

```bash
cd terraform/environments/prod
terraform plan
terraform apply
```

Share with the client after apply:

```bash
terraform output vpc_cidr
terraform output nat_gateway_public_ip   # only if they use HTTPS IP allowlist
```

## Step 5 — Apply infrastructure

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

Allow **15–30+ minutes** (RDS Multi-AZ is slow).

## Step 6 — Post-deploy verification

```bash
terraform output grafana_url
terraform output destroy_protection_enabled   # expect true in prod
```

| Check | How |
|-------|-----|
| ALB healthy | AWS Console → Target group → healthy EC2 targets |
| Grafana API | `curl -s https://YOUR_DOMAIN/api/health` |
| Admin login | `docs/grafana-users.md` — password from Secrets Manager |
| Prometheus | From EC2 via SSM: `curl -s "PROMETHEUS_URL/api/v1/query?query=up"` |
| Datasource | Grafana UI → **Client Prometheus** → Save & test |
| Dashboards | Folders from `grafana/dashboards/` after bootstrap |

### Get admin password

```powershell
cd terraform/environments/prod
$arn = terraform output -raw grafana_config_secret_arn
aws secretsmanager get-secret-value --secret-id $arn --query SecretString --output text `
  | ConvertFrom-Json | Select-Object grafana_admin_user, grafana_admin_password
```

### Shell on Grafana EC2 (SSM)

```bash
aws ssm start-session --target INSTANCE_ID
sudo tail -f /var/log/grafana-bootstrap.log
```

## Step 7 — Dashboards

1. Import client JSON into `grafana/dashboards/client-imported/`.
2. Add your boards under `grafana/dashboards/our-ops/`.
3. Day-to-day: edit in UI; **weekly** export back to Git — `docs/grafana-gitops.md`.

## Step 8 — Users

Add operators via Grafana UI or API — `docs/grafana-users.md`.

## Ongoing operations

| Task | Doc |
|------|-----|
| New AMI | `docs/runbook.md` |
| Scale ASG | `docs/runbook.md` |
| Intentional teardown | `docs/runbook.md` (production section) |

## IAM permissions (deployer)

Your AWS user/role needs permissions to create and manage at minimum: EC2, ASG, ELB, RDS, VPC, Route 53, ACM, Secrets Manager, S3, CloudWatch, IAM roles (for EC2 instance profile), and VPN components if enabled. Use a scoped policy or `PowerUserAccess` + IAM for first deploy, then tighten.

## Related architecture

See `docs/architecture.md` for which tool (Terraform / Packer / Ansible) owns each component, including **EC2 Grafana nodes**.
