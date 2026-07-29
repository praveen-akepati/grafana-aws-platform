# Operations runbook

## Deploy new AMI

1. `packer build` in `packer/`
2. Update `grafana_ami_id` in `terraform.tfvars`
3. `terraform apply` — ASG rolling refresh via launch template version

## Rotate Grafana admin password

1. Update secret in AWS Secrets Manager (`grafana_admin_password`)
2. Run `configure-grafana.yml` against instances or replace instances in ASG

## Scale manually

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <asg_name> \
  --desired-capacity 3
```

## Tear down (POC)

With `poc_mode = true` in `terraform.tfvars` (default in the example file):

- RDS: no deletion protection, no final snapshot, backups disabled (`backup_retention_period = 0`)
- Logs S3 bucket: `force_destroy` so objects do not block destroy
- Secrets Manager: immediate delete (`recovery_window_in_days = 0`)

```bash
cd terraform/environments/prod
terraform destroy
```

After destroy, confirm in the AWS console that EC2, RDS, NAT Gateway, ALB, and VPC are gone. Route 53 records and ACM certs created by this stack are removed with Terraform; **hosted zones and domains you own elsewhere are not deleted.**

For **work production**, set `poc_mode = false` before apply so RDS protection, snapshots, and secret recovery match prod policy.

## Common checks

| Symptom | Check |
|---------|--------|
| 502 from ALB | Target group health, `/var/log/grafana-bootstrap.log` on instances |
| DB errors | RDS security group, credentials in Secrets Manager |
| No Prometheus data | Connectivity to client URL, firewall/VPN routes |

## Alarms

CloudWatch alarms (when SNS email is configured):

- ALB target 5xx
- Unhealthy target count
- RDS CPU > 80%

Logs bucket: ALB access logs under `alb/`, VPC flow logs at bucket root.
