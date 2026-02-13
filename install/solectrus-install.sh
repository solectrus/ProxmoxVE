#!/usr/bin/env bash

# Copyright (c) 2026 Georg Ledermann
# Author: Georg Ledermann
# License: MIT | https://github.com/solectrus/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/solectrus/solectrus

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

SOLECTRUS_URL="https://raw.githubusercontent.com/solectrus/solectrus/refs/heads/develop"
INSTALL_DIR="/opt/solectrus"

# -- Base system ---------------------------------------------------------------
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# -- Docker --------------------------------------------------------------------
msg_info "Setup Docker Repository"
setup_deb822_repo \
  "docker" \
  "https://download.docker.com/linux/$(get_os_info id)/gpg" \
  "https://download.docker.com/linux/$(get_os_info id)" \
  "$(get_os_info codename)" \
  "stable" \
  "$(dpkg --print-architecture)"
msg_ok "Setup Docker Repository"

msg_info "Installing Docker"
$STD apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
msg_ok "Installed Docker"

msg_info "Configuring Docker"
mkdir -p /etc/docker

# Use journald for container logs to prevent unbounded disk usage
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json

systemctl restart docker
msg_ok "Configured Docker"

# -- SOLECTRUS setup -----------------------------------------------------------
msg_info "Setup SOLECTRUS"
mkdir -p "$INSTALL_DIR"

# Fetch compose.yaml and .env template from upstream repository
curl -fsSL "${SOLECTRUS_URL}/compose.yaml" -o "${INSTALL_DIR}/compose.yaml" || {
  msg_error "Failed to download compose.yaml"
  exit 1
}
curl -fsSL "${SOLECTRUS_URL}/.env.example" -o "${INSTALL_DIR}/.env" || {
  msg_error "Failed to download .env.example"
  exit 1
}

# Generate random credentials for all services
cd "$INSTALL_DIR"
POSTGRES_PW=$(openssl rand -base64 24 | tr -d '/+=')
INFLUX_PW=$(openssl rand -base64 24 | tr -d '/+=')
INFLUX_ADMIN_TOKEN=$(openssl rand -base64 48 | tr -d '/+=')
SECRET_KEY=$(openssl rand -hex 64)
ADMIN_PW=$(openssl rand -base64 12 | tr -d '/+=')
CT_IP=$(hostname -I | awk '{print $1}')

# Replace default values in .env with generated credentials and absolute paths
sed -i \
  -e "s|^DB_VOLUME_PATH=.*|DB_VOLUME_PATH=${INSTALL_DIR}/postgresql|" \
  -e "s|^INFLUX_VOLUME_PATH=.*|INFLUX_VOLUME_PATH=${INSTALL_DIR}/influxdb|" \
  -e "s|^REDIS_VOLUME_PATH=.*|REDIS_VOLUME_PATH=${INSTALL_DIR}/redis|" \
  -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PW}|" \
  -e "s|^INFLUX_PASSWORD=.*|INFLUX_PASSWORD=${INFLUX_PW}|" \
  -e "s|^INFLUX_ADMIN_TOKEN=.*|INFLUX_ADMIN_TOKEN=${INFLUX_ADMIN_TOKEN}|" \
  -e "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=${SECRET_KEY}|" \
  -e "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PW}|" \
  -e "s|^APP_HOST=.*|APP_HOST=${CT_IP}|" \
  .env

msg_ok "Setup SOLECTRUS"

# -- InfluxDB read-only token --------------------------------------------------
# Start InfluxDB first so we can create a dedicated read-only token via its API.
# This avoids reusing the admin token for the dashboard (least-privilege).
msg_info "Starting InfluxDB"
$STD docker compose up -d influxdb
for i in {1..30}; do
  curl -sf http://localhost:8086/ping >/dev/null 2>&1 && break
  sleep 2
done
if ! curl -sf http://localhost:8086/ping >/dev/null 2>&1; then
  msg_error "InfluxDB failed to start within 60 seconds"
  exit 1
fi
msg_ok "Started InfluxDB"

msg_info "Creating InfluxDB tokens"
ORG_ID=$(curl -sf http://localhost:8086/api/v2/orgs \
  -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" | jq -r '.orgs[0].id')
if [[ -z "$ORG_ID" || "$ORG_ID" == "null" ]]; then
  msg_error "Failed to retrieve InfluxDB organization ID"
  exit 1
fi

INFLUX_READ_TOKEN=$(curl -sf http://localhost:8086/api/v2/authorizations \
  -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"description\":\"SOLECTRUS read-only\",\"orgID\":\"${ORG_ID}\",\"permissions\":[{\"action\":\"read\",\"resource\":{\"type\":\"buckets\",\"orgID\":\"${ORG_ID}\"}}]}" \
  | jq -r '.token')
if [[ -z "$INFLUX_READ_TOKEN" || "$INFLUX_READ_TOKEN" == "null" ]]; then
  msg_error "Failed to create InfluxDB read-only token"
  exit 1
fi

INFLUX_WRITE_TOKEN=$(curl -sf http://localhost:8086/api/v2/authorizations \
  -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"description\":\"SOLECTRUS write\",\"orgID\":\"${ORG_ID}\",\"permissions\":[{\"action\":\"write\",\"resource\":{\"type\":\"buckets\",\"orgID\":\"${ORG_ID}\"}}]}" \
  | jq -r '.token')
if [[ -z "$INFLUX_WRITE_TOKEN" || "$INFLUX_WRITE_TOKEN" == "null" ]]; then
  msg_error "Failed to create InfluxDB write token"
  exit 1
fi

sed -i "s|^INFLUX_TOKEN_READ=.*|INFLUX_TOKEN_READ=${INFLUX_READ_TOKEN}|" .env
sed -i "s|^INFLUX_TOKEN_WRITE=.*|INFLUX_TOKEN_WRITE=${INFLUX_WRITE_TOKEN}|" .env
msg_ok "Created InfluxDB tokens"

# -- Start all services --------------------------------------------------------
msg_info "Starting SOLECTRUS"
$STD docker compose up -d
msg_ok "Started SOLECTRUS"

# -- Credentials ---------------------------------------------------------------
# Store generated credentials for later reference (convention: ~/app.creds)
{
  echo "SOLECTRUS Credentials"
  echo "Dashboard URL:     http://${CT_IP}:3000"
  echo "Admin Password:    ${ADMIN_PW}"
  echo "Postgres Password: ${POSTGRES_PW}"
  echo "InfluxDB Password: ${INFLUX_PW}"
  echo "InfluxDB Admin Token: ${INFLUX_ADMIN_TOKEN}"
  echo "InfluxDB Read Token:  ${INFLUX_READ_TOKEN}"
  echo "InfluxDB Write Token: ${INFLUX_WRITE_TOKEN}"
} > ~/solectrus.creds
chmod 600 ~/solectrus.creds

# -- Finalize ------------------------------------------------------------------
motd_ssh
customize
cleanup_lxc
