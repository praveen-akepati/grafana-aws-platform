#!/bin/bash
# Run on each Grafana EC2 instance via SSM (one command block or line-by-line).
set -euo pipefail

ALB_HOST="grafan20260729174844349800000001-428684326.ap-south-1.elb.amazonaws.com"
ALB_URL="http://${ALB_HOST}/"

sudo mkdir -p /etc/systemd/system/grafana-server.service.d
sudo tee /etc/systemd/system/grafana-server.service.d/alb-poc.conf >/dev/null <<EOF
[Service]
Environment=GF_SERVER_PROTOCOL=http
Environment=GF_SERVER_DOMAIN=${ALB_HOST}
Environment=GF_SERVER_ROOT_URL=${ALB_URL}
Environment=GF_SECURITY_COOKIE_SECURE=false
EOF

sudo systemctl daemon-reload
sudo systemctl restart grafana-server
systemctl is-active grafana-server
echo "OK — Grafana URL: ${ALB_URL}"
