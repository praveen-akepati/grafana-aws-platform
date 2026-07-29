#!/bin/bash
set -euo pipefail

exec > /var/log/grafana-bootstrap.log 2>&1

REGION="${region}"
SECRETS_ARN="${secrets_arn}"
RDS_ENDPOINT="${rds_endpoint}"
RDS_DATABASE="${rds_database_name}"
GRAFANA_ROOT_URL="${grafana_root_url}"
PROMETHEUS_URL="${prometheus_url}"
ANSIBLE_REPO="${ansible_repo_url}"

apt-get update -y
apt-get install -y python3-pip jq awscli

pip3 install ansible boto3 botocore

mkdir -p /opt/grafana-bootstrap
cat > /opt/grafana-bootstrap/extra-vars.json <<EOF
{
  "grafana_rds_host": "$RDS_ENDPOINT",
  "grafana_rds_database": "$RDS_DATABASE",
  "grafana_root_url": "$GRAFANA_ROOT_URL",
  "prometheus_url": "$PROMETHEUS_URL",
  "grafana_secrets_arn": "$SECRETS_ARN",
  "aws_region": "$REGION"
}
EOF

if [ -n "$ANSIBLE_REPO" ]; then
  git clone "$ANSIBLE_REPO" /opt/grafana-bootstrap/repo
  cd /opt/grafana-bootstrap/repo/ansible
else
  cd /opt/grafana-platform/ansible
fi

ansible-playbook playbooks/configure-grafana.yml \
  -i localhost, \
  -c local \
  -e "@/opt/grafana-bootstrap/extra-vars.json"
