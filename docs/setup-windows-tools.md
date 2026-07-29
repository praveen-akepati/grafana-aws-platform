# Windows tool setup (POC)

## Installed on this machine

| Tool | How | Verify (in **Windows Terminal**) |
|------|-----|----------------------------------|
| AWS CLI | Already present | `aws sts get-caller-identity --profile praveen_iam` |
| Terraform | Chocolatey | `terraform version` |
| Packer | winget + `ngrok update` for ngrok | `packer version` (WSL for **build**) |
| ngrok | winget; run `ngrok update` if &lt; 3.20 | `ngrok version` (need **3.20+**) |
| Ansible | WSL `apt` / pip (not reliable in all Windows shells) | `wsl ansible-playbook --version` |
| Docker Desktop | Installed | Start app, then `docker ps` |
| Git | Already installed | `git --version` |

**Packer build:** use **WSL** — see `docs/packer-build-wsl.md` (Amazon plugin only; no Ansible step during Packer).

**Ansible collections** (WSL, once):

```bash
cd /mnt/c/Users/USER/grafana-aws-platform/ansible
ansible-galaxy collection install -r requirements.yml
```

## You still need to do manually

1. **Docker Desktop** — start before `docker compose up` for local Prometheus.
2. **AWS profile** — `export AWS_PROFILE=praveen_iam` in WSL; in PowerShell: `$env:AWS_PROFILE = "praveen_iam"`.
3. **ngrok** — `ngrok config add-authtoken YOUR_TOKEN` from https://dashboard.ngrok.com/get-started/your-authtoken  
   If agent is old: `ngrok update` (need **≥ 3.20.0**).

## Ansible on Windows

Ansible CLI often fails in embedded shells (`WinError 87`). Use **WSL** for `ansible-galaxy` / optional playbooks. **Runtime** Grafana config runs on **Linux EC2** via user_data, not from your laptop during `terraform apply`.

## Quick readiness check

**Windows Terminal:**

```powershell
$env:AWS_PROFILE = "praveen_iam"
aws sts get-caller-identity --no-cli-pager
terraform version
docker ps
```

**Prometheus + ngrok:** `docs/local-prometheus-before-aws.md`
