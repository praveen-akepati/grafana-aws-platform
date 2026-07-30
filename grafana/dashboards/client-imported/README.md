# Client-imported dashboards

Place dashboard JSON **exported or adapted from the client's GitOps repo** here.

Suggested layout:

```text
client-imported/
  cluster-<name>/
    <dashboard>.json
  application-<name>/
    <dashboard>.json
```

Each subdirectory becomes a Grafana folder. Start with the dashboards the client already uses for Kubernetes clusters and applications; add your own panels or dashboards under `../our-ops/`.

**Before first import:** ensure Prometheus queries use the **Client Prometheus** datasource (see parent `README.md`).
