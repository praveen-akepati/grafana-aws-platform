# Dual Grafana model (your ops vs client environment)

Use this when the **client already has working dashboards and Prometheus on Kubernetes**, but **your company** needs its **own Grafana** in **your AWS network** for **your operational purposes**.

This repository deploys **your** Grafana platform. It does **not** replace or take over the client’s existing monitoring UI.

## Two separate systems

```
┌───────────────────────────── Client company network ─────────────────────────────┐
│  Kubernetes: Prometheus (+ metrics)                                              │
│  Client Grafana / dashboards (unchanged — for their operators)                   │
└───────────────────────────────────────┬──────────────────────────────────────────┘
                                        │
                          VPN / private connectivity (metrics API only)
                                        │
┌───────────────────────────────────────▼──────────────────────────────────────────┐
│  Your company — AWS (this stack)                                                 │
│  HA Grafana + ALB + RDS  →  your operators, your dashboards, your users          │
└──────────────────────────────────────────────────────────────────────────────────┘
```

| | Client environment | Your environment (this repo) |
|---|-------------------|------------------------------|
| **Who uses it** | Client ops teams | **Your** ops / engineering / NOC |
| **Grafana** | Their existing instance | **New** HA Grafana you deploy |
| **Prometheus** | Stays in their K8s | Not hosted by you — **datasource only** |
| **Dashboards** | Their panels and alerts | **You** build or import for **your** workflows |
| **Users & SSO** | Their directory | **Your** users (`docs/grafana-users.md`) |
| **URL** | Their hostname | Your domain / ALB (`terraform output grafana_url`) |
| **Data at rest** | Metrics in their cluster | Grafana DB (users, dashboards) in **your RDS** |

## What you are building

- A **managed Grafana service** for your company on AWS (Terraform + Packer + Ansible in this repo).
- **Read-only consumption** of client metrics via the Prometheus HTTP API (`prometheus_url`).
- **Your** access control, **your** dashboards, **your** runbooks — aligned with how **you** operate the relationship or platform.

## What you are not building

- Replacing the client’s Grafana or forcing a single shared UI.
- Hosting Prometheus or long-term metric storage in your VPC (unless you add that later as a separate decision).
- Automatic copy of the client’s dashboards (unless they export JSON and you import it).
- Client user access to **your** Grafana (unless you choose to invite them).

## What to ask the client for

They usually **already have** Prometheus and internal DNS/Ingress. You need **integration**, not a greenfield metrics stack.

| Ask for | Why |
|---------|-----|
| **Prometheus base URL** reachable from your VPC | Set `prometheus_url` in `terraform.tfvars` |
| **Site-to-site VPN** (preferred) | Stable access without repeated firewall tickets — see `docs/client-prometheus-kubernetes.md` |
| **Read-only API access** | Query `/api/v1/*`; agree auth (token, basic, mTLS) if required |
| **VPC CIDR allowlist** on their side | Your Grafana nodes egress from your private subnets |
| *(Optional)* Dashboard JSON or metric/label conventions | Speeds up building **your** dashboards |

**One-liner for the client:**

> “We will run our own Grafana in our AWS environment for our operational monitoring. Your existing Grafana and dashboards stay as they are. We only need private, read-only access to your Prometheus API.”

## What you deliver internally

1. Deploy this stack (`README.md` deploy order).
2. Connect Prometheus datasource (`prometheus_url` + auth if needed).
3. Onboard **your** users and sync dashboards from **`grafana/dashboards/`** (`docs/grafana-gitops.md`).
4. Restrict ALB ingress (`allowed_ingress_cidrs`) to **your** networks.
5. Operate HA Grafana (AMI updates, backups, `poc_mode = false` in production).

## Related documentation

| Doc | Topic |
|-----|--------|
| `docs/client-prometheus-kubernetes.md` | VPN, hostname, auth, operational stability |
| `docs/grafana-users.md` | Users and access on **your** Grafana |
| `docs/grafana-gitops.md` | Dashboards in Git (`grafana/dashboards/`) |
| `docs/architecture.md` | AWS components and traffic flow |
| `docs/runbook.md` | Day-2 operations and teardown |

## Common misconceptions

| Misconception | Reality |
|---------------|---------|
| “We need their Grafana login” | No — you run **your** Grafana; they expose **Prometheus** (or agree another datasource). |
| “Their dashboard will appear in ours” | No — you configure datasources and build/import dashboards. |
| “We must create prometheus.internal.client.com” | Often **already exists** on their side; confirm URL and reachability from your VPC. |
| “We change something on AWS → client updates firewall” | Avoid IP-only allowlists; use **VPN + CIDR** so routine changes don’t need client tickets. |
