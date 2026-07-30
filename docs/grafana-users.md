# Grafana users and access

This stack creates **one bootstrap admin** in AWS Secrets Manager. Additional users are created in Grafana itself (or via LDAP/OAuth when you add that later). User accounts are stored in **RDS PostgreSQL**, so they are shared across all nodes in the Auto Scaling Group.

## Bootstrap admin (first login)

After `terraform apply`:

1. Open the URL from `terraform output grafana_url`.
2. Retrieve credentials from Secrets Manager (replace profile/region as needed):

**PowerShell:**

```powershell
cd terraform/environments/prod
$arn = terraform output -raw grafana_config_secret_arn
aws secretsmanager get-secret-value --secret-id $arn --query SecretString --output text `
  | ConvertFrom-Json | Select-Object grafana_admin_user, grafana_admin_password
```

**Bash (WSL):**

```bash
cd terraform/environments/prod
ARN=$(terraform output -raw grafana_config_secret_arn)
aws secretsmanager get-secret-value --secret-id "$ARN" --query SecretString --output text | jq -r '.grafana_admin_user, .grafana_admin_password'
```

Default username is **`admin`**. Change the password after first login (or rotate via Secrets Manager — see `docs/runbook.md`).

Self-registration is disabled in `grafana.ini` (`allow_sign_up = false`).

## Add users in the Grafana UI

1. Log in as an org admin.
2. Go to **Administration → Users and access → Users** (menu labels vary slightly by Grafana version).
3. **New user** or **Invite**:
   - Set login, name, and email.
   - Assign role:
     - **Viewer** — view dashboards only
     - **Editor** — create and edit dashboards
     - **Admin** — manage users and settings within the organization

For a small team, this is usually enough.

## Add users via HTTP API

Useful for scripts or automation. Replace URL and credentials:

```bash
curl -u 'admin:YOUR_PASSWORD' -H "Content-Type: application/json" \
  -X POST "https://grafana.example.com/api/admin/users" \
  -d '{
    "name": "Jane Example",
    "email": "jane@example.com",
    "login": "jane",
    "password": "CHANGE_ME",
    "OrgId": 1
  }'
```

Use **HTTPS** and your real `grafana_url` in production.

## Automate with Ansible (optional extension)

The repo already uses `community.grafana`. You can add tasks after datasource configuration in `ansible/roles/grafana/tasks/main.yml` using the `grafana_user` module, driven by a variable list and passwords from Secrets Manager or Ansible Vault.

## Enterprise identity (LDAP / OAuth / SAML)

For many users and central directory login:

1. Extend `ansible/roles/grafana/templates/grafana.ini.j2` with `[auth.ldap]`, `[auth.generic_oauth]`, or `[auth.saml]`.
2. Pass settings via Ansible variables (client IDs, LDAP bind DN, group mappings).
3. Re-run the configure playbook or replace ASG instances.

The ALB `allowed_ingress_cidrs` control **who can reach the site**; Grafana auth controls **who can log in**.

## Security notes

- Do not leave the default `admin` password in production.
- Prefer **Viewer** or **Editor** unless someone needs org admin.
- Keep `allow_sign_up = false` unless you explicitly want open registration behind the ALB.
- For SSO, enforce HTTPS (`use_custom_domain = true`) and restrict ALB ingress to known networks.
