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
