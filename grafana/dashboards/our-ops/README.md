# Our operations dashboards

Dashboards **your team** owns — SLOs, platform health, runbook-oriented views, and anything not copied from the client.

Examples to add over time:

- Client Prometheus `up` / critical job health across clusters
- Your AWS platform signals (optional CloudWatch datasource later)
- Escalation-oriented summary boards for your NOC

Commit JSON here and deploy via Ansible (see `docs/grafana-gitops.md`).
