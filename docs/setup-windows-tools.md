# Windows tool setup (POC)

Tools for a **personal POC** on Windows: optional local Prometheus + ngrok, Packer in WSL, then Terraform deploy. For production client connectivity, see **`docs/setup-windows-tools.md`** on `main` or **`docs/deploy-guide.md`**.

## Required tools

| Tool | Install (typical) | Verify |
|------|-------------------|--------|
| **Git** | [git-scm.com](https://git-scm.com/) or `winget install Git.Git` | `git --version` |
| **AWS CLI v2** | [AWS CLI install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | `aws --version` |
| **Terraform** | [terraform.io](https://developer.hashicorp.com/terraform/install) or Chocolatey/winget | `terraform version` (≥ 1.5) |
| **WSL 2 + Ubuntu** | `wsl --install` then reboot | `wsl -l -v` |
| **Packer** (in WSL) | [HashiCorp install](https://developer.hashicorp.com/packer/install) inside Ubuntu | `wsl packer version` (≥ 1.9) |
| **Docker Desktop** | [Docker Desktop](https://www.docker.com/products/docker-desktop/) | `docker ps` (after starting the app) |
| **ngrok** | [ngrok.com](https://ngrok.com/download) — use **≥ 3.20** | `ngrok version` |

Inside **WSL Ubuntu**, also install:

```bash
sudo apt-get update
sudo apt-get install -y awscli jq unzip
```

**Packer build:** use **WSL** — see `docs/packer-build-wsl.md`.

**Ansible collections** (WSL, once — optional for manual playbooks):

```bash
cd /mnt/c/path/to/grafana-aws-platform/ansible
ansible-galaxy collection install -r requirements.yml
```

## AWS credentials

**PowerShell:**

```powershell
$env:AWS_PROFILE = "your-aws-profile"
$env:AWS_DEFAULT_REGION = "ap-south-1"
aws sts get-caller-identity --no-cli-pager
```

**WSL (for Packer):**

```bash
export AWS_PROFILE=your-aws-profile
export AWS_DEFAULT_REGION=ap-south-1
aws sts get-caller-identity
```

## Manual one-time setup (POC)

1. **Docker Desktop** — start before `docker compose up` for local Prometheus.
2. **ngrok** — `ngrok config add-authtoken YOUR_TOKEN` from https://dashboard.ngrok.com/get-started/your-authtoken  
   If the agent is old: `ngrok update` (need **≥ 3.20.0**).

## Ansible on Windows

Ansible CLI often fails in embedded shells (`WinError 87`). Use **WSL** for `ansible-galaxy` / optional playbooks. **Runtime** Grafana config runs on **Linux EC2** via user_data.

## Optional: AWS Session Manager

Shell on private EC2 without a bastion — see `docs/runbook.md`.

## Quick readiness check

**Windows Terminal:**

```powershell
$env:AWS_PROFILE = "your-aws-profile"
aws sts get-caller-identity --no-cli-pager
terraform version
docker ps
ngrok version
```

**WSL:**

```bash
packer version
aws sts get-caller-identity
```

**Local Prometheus + ngrok:** `docs/local-prometheus-before-aws.md`
