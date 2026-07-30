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

## Recommended workflow: UI edits + weekly Git sync

**Default for this project:** keep `allowUiUpdates: true` in `grafana/dashboards/provisioning/dashboards.yml`.

| Layer | Role |
|-------|------|
| **Grafana UI** | Day-to-day — add panels, tweak queries, fix layouts |
| **Git (`grafana/dashboards/`)** | Weekly (or after major changes) — export from UI so Git matches production |
| **File provisioning** | Loads Git dashboards on **new instances** and after Ansible sync |

```text
Mon–Fri:   edit dashboards in the UI
Weekly:    export JSON from UI → commit to grafana/dashboards/
Deploy:    Git → instances (Ansible / new AMI / instance refresh)
```

Sync direction is **Grafana UI → Git**, not the other way around for routine updates. Ansible and provisioning push **Git → Grafana** when you deploy or replace instances.

### Why weekly export matters (RDS)

Grafana stores dashboards in **RDS PostgreSQL**. UI saves go to the database. Files under `grafana/dashboards/` are loaded via provisioning on bootstrap.

Without periodic export, **Git can fall behind** what operators see in the UI. Weekly export keeps Git aligned for:

- Version history and review
- New ASG instances and disaster recovery
- Sharing the same dashboards across environments

### Weekly sync checklist

1. List dashboards **created or edited** since the last sync (ask the team in standup or a shared channel).
2. For each dashboard:
   - Open in Grafana → **Dashboard settings** → **JSON Model** (copy), or **Share → Export → Save to file**.
3. Save to the correct repo path:
   - Client-based → `grafana/dashboards/client-imported/<cluster-or-app>/<name>.json`
   - Your team's → `grafana/dashboards/our-ops/<name>.json`
   - **New** dashboards that exist only in the UI must be exported as **new** `.json` files.
4. Before commit:
   - Datasource references point to **Client Prometheus**
   - No secrets or API keys in JSON
   - Filename describes the dashboard clearly
5. Commit and push, e.g. `chore(grafana): weekly dashboard sync 2026-07-30`.
6. **Optional:** re-run `configure-grafana.yml` if you need files on disk to match Git immediately on all nodes.

**Cadence:** weekly is enough for many teams; export sooner after large changes or before an AMI refresh.

### Adding panels after initial import

Panels live **inside** each dashboard `.json` file (there is no separate panel file).

1. Add or edit panels in the UI during the week.
2. On sync day, **re-export the whole dashboard** and overwrite the matching file in Git.
3. Do not rely on UI-only changes without export — they are in RDS but missing from Git until you sync.

### Risks to avoid

| Risk | Mitigation |
|------|------------|
| UI changes never exported | Weekly reminder; export after significant edits |
| Two people edit the same dashboard | Own folders per team; use PRs for weekly sync |
| New dashboard only in UI | Export the same week |
| Broken datasource after export | Fix UID to **Client Prometheus**, re-export once |

### Evolution

| Stage | Practice |
|-------|----------|
| **Now** | `allowUiUpdates: true` + weekly UI → Git export |
| **Later** | Export after each material change; optional API/script to open a PR |
| **Mature** | `allowUiUpdates: false` and every change via Git PR (stricter GitOps) |

## Workflow (strict Git-only alternative)

```text
Edit JSON in grafana/dashboards/ → PR / review → merge to main
    → re-run Ansible on instances OR new AMI + ASG instance refresh
```

Use this when `allowUiUpdates: false` or for teams that prefer never editing in the UI.

Same outcome as the client's Argo CD sync, but the deploy mechanism is **Ansible/CI** because Grafana runs on **EC2**, not Kubernetes.

### Strict Git-only (`allowUiUpdates: false`)

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
