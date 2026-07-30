# Grafana dashboards (Git source of truth)

Dashboard JSON files in this folder are synced to Grafana via **file provisioning** on each instance bootstrap (Ansible).

## Folder layout

```text
grafana/dashboards/
  provisioning/
    dashboards.yml          # Grafana provider config
  client-imported/          # Starting point: exports adapted from the client's Git / Grafana
    <cluster-or-app>/       # Optional subfolders (become Grafana folders)
      *.json
  our-ops/                  # Dashboards your team adds for your operational needs
    *.json
```

Subdirectories under `client-imported/` and `our-ops/` become **Grafana folders** (`foldersFromFilesStructure: true`).

## Add client dashboards (starting point)

1. Get dashboard JSON from the client (export from their Grafana UI, or copy from their GitOps repo with permission).
2. Save under `client-imported/`, grouped by cluster or application, e.g.:

   ```text
   client-imported/
     prod-cluster-a/
       node-exporter.json
     prod-cluster-b/
       apps-overview.json
   ```

3. **Retarget the Prometheus datasource** in each JSON file to **Client Prometheus** (the datasource Ansible creates). In exported JSON, update `datasource` fields — often:

   ```json
   "datasource": { "type": "prometheus", "uid": "client-prometheus" }
   ```

   After first deploy, check the real UID in Grafana (**Connections → Data sources → Client Prometheus → UID**) and align JSON, or re-export after fixing one dashboard in the UI.

4. Commit to Git → rebuild AMI or re-run `configure-grafana.yml` / replace ASG instances.

**Day-to-day:** edit in the Grafana UI (`allowUiUpdates: true`). **Weekly:** export JSON back to this folder so Git stays in sync — see **`docs/grafana-gitops.md`** (recommended workflow).

## Add your own dashboards

1. Create or export JSON into `our-ops/` (optionally in subfolders).
2. Commit and deploy the same way.
3. Prefer editing JSON in Git over long-term UI-only changes.

## Do not commit secrets

Dashboard JSON must not contain API keys or client credentials. Use Grafana datasource auth configured in Ansible / Secrets Manager.
