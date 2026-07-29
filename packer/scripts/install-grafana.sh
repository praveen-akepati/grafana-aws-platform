#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

wait_for_apt() {
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done
  while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 2; done
}

cloud-init status --wait || true
wait_for_apt

apt-get update -y
apt-get upgrade -y

apt-get install -y \
  apt-transport-https \
  software-properties-common \
  wget \
  curl \
  jq \
  git \
  python3-pip \
  awscli \
  gpg

curl -fsSL -o /tmp/amazon-cloudwatch-agent.deb \
  https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb || apt-get install -f -y

wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list

apt-get update -y
apt-get install -y grafana

systemctl disable grafana-server

pip3 install ansible boto3 botocore

mkdir -p /opt/grafana-platform
