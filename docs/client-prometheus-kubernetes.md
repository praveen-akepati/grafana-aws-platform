# Client Prometheus on Kubernetes (cross-company connectivity)

In production, **Grafana runs in your company’s AWS VPC** (this stack). **Prometheus runs in the client’s Kubernetes cluster** on their corporate network. The two networks do not share a LAN by default — you must design connectivity and security **before** go-live.

> **Context:** If the client already has their own Grafana/dashboards and you are hosting **separate Grafana for your ops**, read **`docs/dual-grafana-model.md`** first.

## Who talks to whom

```
[Your users] → ALB → Grafana EC2 (private subnet) → ??? → [Client K8s] Prometheus
```

Important details:

| Topic | Behavior |
|-------|----------|
| **Grafana datasource mode** | **Proxy** — the browser does not call Prometheus. Each Grafana EC2 node calls Prometheus from the **private subnet**. |
| **Egress path** | Private subnet → **NAT Gateway** → internet or **VPN** → client network. |
| **Ingress to Grafana** | Controlled by `allowed_ingress_cidrs` on the ALB (your users / offices). |
| **Ingress to Prometheus** | Controlled by the **client** (firewall, K8s NetworkPolicy, Ingress, VPN routes). |

`prometheus_url` in `terraform.tfvars` must be a URL that **Grafana EC2 instances can resolve and reach**, not a URL that only works on a developer laptop.

## Common connectivity patterns

Choose with the client based on security policy, who operates the networks, and time to implement.

### Option A — Site-to-site VPN (recommended for private Prometheus)

**Best when:** Prometheus stays **internal** (ClusterIP or private hostname), no public exposure.

```
Grafana VPC (10.0.0.0/16) ←—— IPsec VPN ——→ Client network (e.g. 172.16.0.0/12)
                                                      ↓
                                              K8s Prometheus :9090
```

**Your side (AWS):**

1. Set `enable_client_vpn = true` in `terraform.tfvars` (see `terraform.tfvars.example`).
2. After apply, share with the client:
   ```bash
   terraform output vpc_cidr
   terraform output nat_gateway_public_ip   # only for HTTPS IP allowlist pilot
   ```
3. Add routes via the VPN module (`terraform/modules/vpn`) — wired when `enable_client_vpn` is true.

**Client side:**

1. Terminate IPsec on their firewall or cloud VPN gateway (public IP → `customer_gateway_ip` in Terraform).
2. Advertise or static-route their **Kubernetes node / service CIDRs** (or a dedicated Prometheus VIP) to your VPC CIDR.
3. Expose Prometheus on an **internal** DNS name, e.g. `https://prometheus.internal.client.com` or `http://10.20.30.40:9090`.
4. Allow **TCP 9090** (or 443 if TLS Ingress) from your **VPC CIDR** — not from `0.0.0.0/0`.

**`prometheus_url` example:**

```hcl
prometheus_url = "http://prometheus.monitoring.svc.cluster.local:9090"
# or client internal FQDN / LB VIP reachable only over VPN
prometheus_url = "https://prometheus.internal.client.example.com"
```

Use **HTTPS** and auth on the client endpoint when possible.

---

### Option B — Client Ingress over HTTPS + IP allowlist

**Best when:** VPN is slow to approve as a **temporary** bridge — not ideal long term (see [Operational stability](#operational-stability-avoid-repeated-client-changes)).

```
Grafana EC2 → NAT Gateway (fixed EIP) → Internet → Client Ingress → Prometheus
```

**Client side (Kubernetes):**

1. Expose Prometheus via **Ingress** (nginx, ALB Ingress Controller, etc.) — often in front of `kube-prometheus-stack` or Prometheus Operator.
2. TLS certificate on the Ingress hostname.
3. **Restrict source IPs** to your AWS **NAT Gateway Elastic IP(s)** (one per AZ if you use one NAT per AZ).
4. Optional: **Basic auth**, **OAuth2 proxy**, or **mTLS** in front of Prometheus.

**Your side:**

1. Note NAT Gateway EIPs after `terraform apply` (VPC → NAT gateways, or add Terraform outputs).
2. Give those EIPs to the client for their firewall / Ingress `whitelist-source-range`.
3. Set:

```hcl
prometheus_url = "https://prometheus.client.example.com"
```

If the client requires a custom header or bearer token, configure it in Grafana (**Connections → Data sources → HTTP headers**) or extend the Ansible `grafana_datasource` task with `json_data` / `secure_json_data`.

---

## Operational stability (avoid repeated client changes)

You should **not** design production so every AWS tweak needs a client firewall ticket. Patterns ranked by how often the client must act:

| Approach | Client changes when… | Recommended? |
|----------|----------------------|--------------|
| **Site-to-site VPN + allow VPC CIDR** | You change **VPC CIDR** or they renumber K8s (rare) | **Yes — preferred** |
| **HTTPS + auth (token / mTLS)** | You rotate credentials (planned); IP can be secondary | **Yes — combine with VPN or as backup** |
| **HTTPS + NAT EIP allowlist only** | NAT/EIP rebuild, new region, second NAT, full stack recreate | **Avoid as sole control** |

### Why NAT EIP allowlists are brittle

The stack already has **one Elastic IP** on the NAT Gateway. That IP is *usually* stable, but the client must be involved again if:

- You **destroy and recreate** the Terraform stack (new EIP).
- The **NAT Gateway or EIP** is replaced (incident, refactor, region move).
- You add **another NAT** (multi-AZ egress) — more IPs to allowlist.
- You run a **second environment** (staging Grafana) — more IPs or CIDRs.

Grafana **ASG scale-out/in** does **not** change egress IP — all nodes use the same NAT. The problem is **infrastructure** changes, not day-to-day Grafana ops.

### What to agree with the client up front

1. **One-time VPN** (Option A): they allow your **`vpc_cidr`** (e.g. `10.0.0.0/16`) to reach Prometheus on an **internal hostname**. You change AMIs, instance count, or NAT without calling them.
2. **Stable DNS**: `prometheus_url` is a **hostname** they control, not a raw IP that changes when pods move.
3. **Authentication**: bearer token, basic auth, or mTLS on Prometheus/Ingress — so security does not depend only on IP.
4. **Change window** (if you must use public IP allowlist): document that EIP changes are **exceptional** and need 48h notice — still worse than VPN.

### Practical recommendation

| Phase | Approach |
|-------|----------|
| **Production** | VPN + internal client URL + HTTPS/auth |
| **Pilot only** | HTTPS + NAT EIP allowlist, with a plan to move to VPN |
| **Never** | Rely on IP allowlist alone with no auth |

---

### Option C — Client-managed API gateway / reverse proxy

**Best when:** Security team wants a single controlled API front door.

The client runs a gateway (Kong, Apigee, AWS API Gateway in their account, etc.) that:

- Terminates TLS
- Authenticates your Grafana (API key, mTLS, IP allowlist)
- Proxies `/api/v1/*` to Prometheus inside the cluster

`prometheus_url` points at the **gateway base URL**, not the raw Pod IP.

---

### Option D — Both companies on AWS (advanced)

If the client cluster is also on AWS, alternatives include **VPC peering**, **Transit Gateway**, or **PrivateLink** (client exposes a private endpoint in their VPC, you connect from yours). Same rules apply: routes + security groups + private DNS — coordinate CIDRs so they do not overlap with `var.vpc_cidr`.

## Kubernetes-specific notes (for the client team)

Typical stack: **kube-prometheus-stack** / Prometheus Operator.

| Exposure | Client action |
|----------|----------------|
| **ClusterIP only** | Requires VPN/peering; Grafana must be on a network that can route to the Service CIDR or a port-forward/LB in-cluster. |
| **Internal LoadBalancer** | Private LB hostname reachable over VPN; use that hostname in `prometheus_url`. |
| **Ingress (public or private)** | Hostname + TLS; restrict by source IP or auth. |

Prometheus HTTP API paths used by Grafana:

- `GET /api/v1/query`
- `GET /api/v1/query_range`
- `GET /api/v1/label/...`

**Do not** point Grafana at a URL that returns HTML login pages (common misconfiguration with unauthenticated Ingress).

## Configure this repository

1. Agree connectivity pattern with the client (A/B/C).
2. Set in `terraform/environments/prod/terraform.tfvars`:

```hcl
prometheus_url = "https://prometheus.client.example.com"
```

3. `terraform apply` — user_data / Ansible registers the **Client Prometheus** datasource on each new instance.
4. If the URL or auth changes later, update tfvars and **replace ASG instances** or re-run `ansible/playbooks/configure-grafana.yml`.

## Verify connectivity (before blaming Grafana)

Run from a **Grafana EC2 instance** (SSM Session Manager or bastion), not from your laptop:

```bash
# Replace with client's URL
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://prometheus.client.example.com/api/v1/query?query=up"
```

Expect HTTP **200** and JSON with `"status":"success"`.

From the Grafana UI: **Connections → Data sources → Client Prometheus → Save & test**.

In **Explore**, run query `up`.

## Split responsibility checklist

### Your company (Grafana host)

- [ ] Agree **VPN + VPC CIDR** access with client (preferred — one-time setup)
- [ ] VPN module configured and routes propagated (if Option A)
- [ ] `prometheus_url` set to a **stable client hostname**
- [ ] Confirm egress from private subnets (VPN or NAT) works
- [ ] ALB access limited with `allowed_ingress_cidrs`
- [ ] If using NAT EIP allowlist: document EIP and **change process** (interim only)

### Client company (Prometheus on K8s)

- [ ] Prometheus URL stable (DNS or LB hostname)
- [ ] Firewall / NetworkPolicy allows **your VPC CIDR** (VPN) or NAT EIPs (pilot only)
- [ ] TLS and **authentication** (not IP-only) on the Prometheus endpoint
- [ ] Ingress/controller health checks pass for `/api/v1/query?query=up`
- [ ] Named contact only for **network/CIDR** changes, not for your routine Grafana scaling

## Security recommendations

- Prefer **VPN or private connectivity** over public Ingress when metrics are sensitive.
- Never use `0.0.0.0/0` on Prometheus Ingress in production.
- Use **HTTPS** and **auth** (basic, bearer token, or OAuth2 proxy) on client endpoints.
- Rotate credentials via Secrets Manager and extend Ansible if headers/tokens must be automated.
- Document that **all Grafana ASG nodes** share the same egress path (NAT EIPs or VPN).

## Related repo files

| File | Purpose |
|------|---------|
| `terraform/modules/vpn` | Site-to-site VPN stub (customer gateway + VGW + routes) |
| `terraform/environments/prod/variables.tf` | `prometheus_url`, `vpc_cidr`, `allowed_ingress_cidrs` |
| `ansible/roles/grafana/tasks/main.yml` | Registers Prometheus datasource (proxy mode) |
| `docs/architecture.md` | High-level traffic diagram |

For a **local laptop POC** (ngrok), use branch `cursor/poc-alb-dns-no-domain` — that path is not for cross-company production.
