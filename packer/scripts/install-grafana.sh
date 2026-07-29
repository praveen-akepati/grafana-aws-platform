#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

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
  amazon-cloudwatch-agent

wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list

apt-get update -y
apt-get install -y grafana

systemctl enable grafana-server

pip3 install ansible boto3 botocore

ansible-galaxy collection install amazon.aws community.grafana

mkdir -p /opt/grafana-platform
