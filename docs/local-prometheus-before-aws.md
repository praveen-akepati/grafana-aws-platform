# Local Prometheus (prepare before AWS deploy)

Grafana runs in a **private VPC on AWS**. It must reach your PC over the **public internet** (via your NAT gateway). `localhost` on your laptop is **not** visible to AWS.

Do this **before** `terraform apply` so you can set `prometheus_url` in `terraform.tfvars` and avoid extra AWS hours debugging connectivity.

## 1. Start Prometheus on your PC

From the repo root:

```powershell
cd poc\local-prometheus
docker compose up -d
```

Check locally:

- UI: http://localhost:9090
- Targets: http://localhost:9090/targets — `prometheus` and `demo` should be **UP**

Stop when not testing:

```powershell
docker compose down
```

## 2. Expose Prometheus with a tunnel (required for AWS)

Pick one tool and install it **before** deploy day.

### Option A — ngrok (fastest POC)

1. Sign up at https://ngrok.com and install ngrok.
2. With Prometheus running:

   ```powershell
   ngrok http 9090
   ```

3. Copy the **HTTPS** forwarding URL, e.g. `https://abc123.ngrok-free.app`
4. Use in Terraform (no trailing slash):

   ```hcl
   prometheus_url = "https://abc123.ngrok-free.app"
   ```

**Note:** Free ngrok URLs change when you restart ngrok. Start ngrok **before** `terraform apply` and keep it running during the POC. If the URL changes, update `prometheus_url` and re-run Ansible or replace ASG instances.

### Option B — Cloudflare Tunnel (more stable hostname)

1. Install `cloudflared` and create a tunnel to `http://localhost:9090`.
2. Use the Cloudflare hostname as `prometheus_url`.

## 3. Verify AWS can reach you (before paying for full stack)

From any external network check (or PowerShell on your PC):

```powershell
Invoke-WebRequest -Uri "https://YOUR-TUNNEL-URL/api/v1/query?query=up" -Headers @{"ngrok-skip-browser-warning"="true"} -UseBasicParsing
```

You should see JSON with `"status":"success"` in the content. Without the header, ngrok free tier returns a browser warning page (`ERR_NGROK_6024`) instead of Prometheus JSON.

Grafana uses the same path (`/api/v1/...`) via **proxy** mode. The Ansible role adds the ngrok skip header when `prometheus_url` contains `ngrok`.

## 4. Windows firewall

Allow inbound **9090** only if you use **port forwarding** instead of a tunnel. For **ngrok/cloudflared**, you usually **do not** need to open 9090 on the router—only the tunnel client outbound.

## 5. Wire into Terraform (do this before `terraform apply`)

In `terraform/environments/prod/terraform.tfvars`:

```hcl
prometheus_url = "https://YOUR-TUNNEL-URL"
```

User data / Ansible will register the **Client Prometheus** datasource on instance boot.

## 6. Order of operations on deploy day

1. `docker compose up -d` (Prometheus)
2. Start tunnel (ngrok / cloudflared)
3. Confirm tunnel URL with `curl` query above
4. Put URL in `terraform.tfvars` + `grafana_ami_id`
5. `terraform apply`
6. Open `terraform output grafana_url` → login → Explore → Prometheus

## 7. Security (short POC)

- Tunnel URL is **public**; anyone with the URL can query metrics.
- Use a **new ngrok URL each POC** and tear down when done.
- Do not expose production or sensitive metrics on an open tunnel.
