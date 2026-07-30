# Operations runbook

## Deploy new AMI

1. `packer build` in WSL — see `docs/packer-build-wsl.md`
2. Update `grafana_ami_id` in `terraform.tfvars`
3. `terraform apply` — ASG rolling refresh via launch template version

## Rotate Grafana admin password

1. Update secret in AWS Secrets Manager (`grafana_admin_password`)
2. Run `configure-grafana.yml` against instances or replace instances in ASG

See `docs/grafana-users.md` for adding non-admin users.

## Client handoff (after apply)

Share with the client for VPN or firewall setup:

```bash
cd terraform/environments/prod
terraform output vpc_cidr
terraform output nat_gateway_public_ip
```

Prefer **VPC CIDR** over NAT IP when possible — see `docs/client-prometheus-kubernetes.md`.

## Access Grafana EC2 (SSM)

Instances use `AmazonSSMManagedInstanceCore`. No bastion required:

```bash
aws ec2 describe-instances --filters "Name=tag:Role,Values=grafana" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text

aws ssm start-session --target i-INSTANCE_ID
sudo tail -100 /var/log/grafana-bootstrap.log
```

## Scale manually

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <asg_name> \
  --desired-capacity 3
```

## Tear down (POC / sandbox)

With `poc_mode = true` in `terraform.tfvars`:

- RDS: no deletion protection, no final snapshot, backups disabled (`backup_retention_period = 0`)
- Logs S3 bucket: `force_destroy` so objects do not block destroy
- Secrets Manager: immediate delete (`recovery_window_in_days = 0`)
- Terraform `destroy_guard` removed when `poc_mode = true` and destroy protection is off

```bash
cd terraform/environments/prod
terraform destroy
```

## Tear down (production — intentional only)

Production uses **two layers** against accidental deletion:

| Layer | What it does |
|-------|----------------|
| **Terraform** | `terraform_data.destroy_guard` with `prevent_destroy` when `destroy_protection` is enabled |
| **AWS** | RDS `deletion_protection`; logs S3 without `force_destroy`; secrets 7-day recovery window |

Check current state:

```bash
terraform output destroy_protection_enabled
```

To remove the stack **on purpose**:

1. In `terraform.tfvars`, set:
   ```hcl
   poc_mode                  = true
   enable_destroy_protection = false
   ```
2. `terraform apply` — disables AWS/Terraform guards (required before destroy).
3. `terraform destroy`
4. Confirm in the AWS console that EC2, RDS, NAT Gateway, ALB, and VPC are gone.

Route 53 records and ACM certs created by this stack are removed with Terraform; **hosted zones and domains you own elsewhere are not deleted.**

For **work production**, keep `poc_mode = false` (and leave `enable_destroy_protection` unset or `true`) so RDS protection, snapshots, secret recovery, and destroy guardrails stay active.

## Common checks

| Symptom | Check |
|---------|--------|
| 502 from ALB | Target group health, `/var/log/grafana-bootstrap.log` on instances |
| DB errors | RDS security group, credentials in Secrets Manager |
| No Prometheus data | `docs/client-prometheus-kubernetes.md` — VPN/routes, client Ingress allowlist (NAT EIPs), auth headers; test `curl` from Grafana EC2 |

## Alarms

CloudWatch alarms (when SNS email is configured):

- ALB target 5xx
- Unhealthy target count
- RDS CPU > 80%

Logs bucket: ALB access logs under `alb/`, VPC flow logs at bucket root.
