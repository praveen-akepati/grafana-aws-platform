# Windows tool setup (production)

Tools you need on a **Windows** workstation to build the AMI and deploy this stack. Runtime Grafana configuration runs on **Linux EC2** via user_data — you do not run Ansible from Windows during a normal `terraform apply`.

## Required tools

| Tool | Install (typical) | Verify |
|------|-------------------|--------|
| **Git** | [git-scm.com](https://git-scm.com/) or `winget install Git.Git` | `git --version` |
| **AWS CLI v2** | [AWS CLI install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | `aws --version` |
| **Terraform** | [terraform.io](https://developer.hashicorp.com/terraform/install) or Chocolatey/winget | `terraform version` (≥ 1.5) |
| **WSL 2 + Ubuntu** | `wsl --install` then reboot | `wsl -l -v` |
| **Packer** (in WSL) | [HashiCorp install](https://developer.hashicorp.com/packer/install) inside Ubuntu | `wsl packer version` (≥ 1.9) |

Inside **WSL Ubuntu**, also install:

```bash
sudo apt-get update
sudo apt-get install -y awscli jq unzip
# Install Packer per HashiCorp docs if not already present
```

Packer builds must run in **WSL** — see `docs/packer-build-wsl.md`.

## AWS credentials

Configure a named profile (replace with your profile name):

**PowerShell (Windows Terminal):**

```powershell
$env:AWS_PROFILE = "your-aws-profile"
$env:AWS_DEFAULT_REGION = "ap-south-1"
aws sts get-caller-identity
```

**WSL (for Packer):**

```bash
export AWS_PROFILE=your-aws-profile
export AWS_DEFAULT_REGION=ap-south-1
aws sts get-caller-identity
```

Use the same profile/region as in `terraform.tfvars`.

## Optional tools

| Tool | When you need it |
|------|------------------|
| **Ansible** (WSL) | Re-run `configure-grafana.yml` manually after a failed bootstrap or password rotation |
| **AWS Session Manager** | Shell on private EC2 instances without a bastion (requires SSM agent + IAM on instances) |

Ansible on native Windows shells is unreliable; use WSL:

```bash
cd /mnt/c/path/to/grafana-aws-platform/ansible
pip3 install ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook --version
```

## Not required on your laptop for production

- **Docker** — not used for this deploy path
- **ngrok** — only for personal POC on branch `cursor/poc-alb-dns-no-domain`
- **Local Prometheus** — metrics live at the **client**; set `prometheus_url` in `terraform.tfvars` when that endpoint is reachable from AWS

## Readiness check

**PowerShell:**

```powershell
git --version
aws sts get-caller-identity --no-cli-pager
terraform version
```

**WSL:**

```bash
packer version
aws sts get-caller-identity
```

If all commands succeed, proceed with `docs/packer-build-wsl.md` then Terraform apply in the README.
