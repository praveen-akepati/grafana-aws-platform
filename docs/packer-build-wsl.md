# Packer AMI build (WSL)

Packer **only creates a Grafana golden AMI**. It does **not** deploy VPC, ALB, RDS, or the ASG — use Terraform for that.

## Prerequisites

- WSL Ubuntu with **AWS CLI**, **Packer**, and AWS credentials configured
- Region: match your `terraform.tfvars` (default **ap-south-1**)

```bash
export AWS_PROFILE=your-profile
export AWS_DEFAULT_REGION=ap-south-1
aws sts get-caller-identity
```

## Build

```bash
cd /path/to/grafana-aws-platform/packer
packer init grafana.pkr.hcl
packer build -var region=ap-south-1 grafana.pkr.hcl
```

Build takes about **15–25 minutes** (temporary builder EC2 + AMI wait). Cost is usually **cents to low dollars**.

## What the template does

1. **Shell provisioner** (as root): install Grafana, CloudWatch agent (`.deb`), `awscli`, `boto3`; leave `grafana-server` disabled until Ansible configures it
2. **File provisioner**: copy `ansible/` to `/opt/grafana-platform/ansible` on the image
3. **No Ansible provisioner** during Packer — runtime config runs on EC2 via **user_data** (`configure-grafana.yml`)

## Success output

```text
AMI: ami-0xxxxxxxxxxxxxxxxx
--> amazon-ebs.grafana: AMIs were created:
ap-south-1: ami-0xxxxxxxxxxxxxxxxx
```

Set in `terraform/environments/prod/terraform.tfvars`:

```hcl
grafana_ami_id = "ami-0xxxxxxxxxxxxxxxxx"
```

## Common errors (fixed in repo)

| Error | Fix |
|-------|-----|
| apt lock / permission denied | Script runs with `sudo`; waits for cloud-init |
| `amazon-cloudwatch-agent` not in apt | Installed from Amazon `.deb` |
| Ansible role not found during Packer | Ansible provisioner removed; use shell + file only |

## Windows Packer

You can install Packer on Windows, but **run `packer build` from WSL** so paths and AWS credentials match what we tested.
