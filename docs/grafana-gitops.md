# Grafana dashboard GitOps (this repo)

The client may use **Argo CD + Git** for their Grafana. This stack uses the **same principle** — **Git is the source of truth** — with dashboards in **`grafana/dashboards/`** and Ansible applying them to EC2 instances.

## Layout in this repository

```text
grafana/dashboards/
  provisioning/dashboards.yml   # Tells Grafana to load JSON from /etc/grafana/dashboards
  client-imported/              # Client dashboards (starting point)
  our-ops/                      # Your team's additional dashboards
```

| Folder | Purpose |
|--------|---------|
| **`client-imported/`** | Dashboards adapted from the client's existing panels (multi-cluster, apps, etc.) |
| **`our-ops/`** | Dashboards you add for **your** operational requirements |
| **`provisioning/`** | Grafana file provider config (do not put JSON here) |

Subfolders become Grafana folders automatically (e.g. `client-imported/prod-cluster-a/overview.json`).

## How it reaches Grafana

1. **Packer** copies `grafana/` to `/opt/grafana-platform/grafana` on the AMI.
2. **Ansible** (`configure-grafana.yml` on boot or manual run) copies:
   - `provisioning/dashboards.yml` → `/etc/grafana/provisioning/dashboards/`
   - JSON trees → `/etc/grafana/dashboards/`
3. Grafana reloads provisioning (restart or `updateIntervalSeconds: 30`).

## Workflow (day to day)

```text
Edit JSON in grafana/dashboards/ → PR / review → merge to main
    → re-run Ansible on instances OR new AMI + ASG instance refresh
```

Same outcome as the client's Argo CD sync, but the deploy mechanism is **Ansible/CI** because Grafana runs on **EC2**, not Kubernetes.

### Strict Git-only (optional, production)

In `grafana/dashboards/provisioning/dashboards.yml`, set:

```yaml
allowUiUpdates: false
```

UI edits will not persist across reprovision — all changes must go through Git.

## Importing client dashboards

1. Obtain JSON (export from their Grafana, or copy from their Git repo with agreement).
2. Place under `grafana/dashboards/client-imported/<group>/`.
3. Fix **datasource** references to match **Client Prometheus** (created by Ansible).
4. Remove client-specific links/alerts/contact points that point to **their** systems, or replace with yours.
5. Commit and deploy.

You are **not** wiring Argo CD to your Grafana. You **reuse their dashboard definitions** as a starting point in **your** Git.

## Adding your own dashboards

1. Build in Grafana UI on a dev instance **or** author JSON by hand.
2. Export JSON → save under `grafana/dashboards/our-ops/`.
3. Commit to this repo.

## Deploy after Git changes

**Option A — Re-run Ansible** (fastest for dashboard-only changes):

```bash
# On each instance via SSM, or from a host that can reach them:
cd /opt/grafana-platform/ansible
ansible-playbook playbooks/configure-grafana.yml -i localhost, -c local \
  -e "@/opt/grafana-bootstrap/extra-vars.json"
```

**Option B — ASG instance refresh** after a new AMI that includes updated `grafana/` files.

**Option C — CI** (recommended later): GitHub Actions on merge to `main` runs Ansible against instances via SSM.

## Alerts (phase 2)

Grafana **unified alerting** is enabled in `grafana.ini`. Alert rules can be added later under:

```text
grafana/alerting/          # future: provisioning YAML for alert rules
```

Keep alert notification channels (Slack, PagerDuty) **yours**, not the client's Argo-managed routes.

## Related docs

- `docs/dual-grafana-model.md` — why you have a separate Grafana from the client
- `docs/client-prometheus-kubernetes.md` — reaching client Prometheus
- `grafana/dashboards/README.md` — quick reference in the dashboards tree
