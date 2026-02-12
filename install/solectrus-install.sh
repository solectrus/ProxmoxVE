#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Georg Ledermann
# License: MIT | https://github.com/solectrus/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/solectrus/solectrus

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

SOLECTRUS_URL="https://raw.githubusercontent.com/solectrus/solectrus/refs/heads/develop"
INSTALL_DIR="/opt/solectrus"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

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
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
systemctl restart docker
msg_ok "Configured Docker"

msg_info "Setup SOLECTRUS"
mkdir -p "$INSTALL_DIR"

# Download compose.yaml and .env from upstream
curl -fsSL "${SOLECTRUS_URL}/compose.yaml" -o "${INSTALL_DIR}/compose.yaml"
curl -fsSL "${SOLECTRUS_URL}/.env.example" -o "${INSTALL_DIR}/.env"

# Generate credentials
cd "$INSTALL_DIR"
POSTGRES_PW=$(openssl rand -base64 24 | tr -d '/+=')
INFLUX_PW=$(openssl rand -base64 24 | tr -d '/+=')
INFLUX_ADMIN_TOKEN=$(openssl rand -base64 48 | tr -d '/+=')
SECRET_KEY=$(openssl rand -hex 64)
ADMIN_PW=$(openssl rand -base64 12 | tr -d '/+=')
CT_IP=$(hostname -I | awk '{print $1}')

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

msg_info "Starting InfluxDB"
$STD docker compose up -d influxdb
until curl -sf http://localhost:8086/ping >/dev/null 2>&1; do sleep 2; done
msg_ok "Started InfluxDB"

# Create read-only token via InfluxDB API
msg_info "Creating InfluxDB read-only token"
ORG_ID=$(curl -sf http://localhost:8086/api/v2/orgs \
  -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" | jq -r '.orgs[0].id')
INFLUX_READ_TOKEN=$(curl -sf http://localhost:8086/api/v2/authorizations \
  -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"description\":\"SOLECTRUS read-only\",\"orgID\":\"${ORG_ID}\",\"permissions\":[{\"action\":\"read\",\"resource\":{\"type\":\"buckets\",\"orgID\":\"${ORG_ID}\"}}]}" \
  | jq -r '.token')
sed -i "s|^INFLUX_TOKEN_READ=.*|INFLUX_TOKEN_READ=${INFLUX_READ_TOKEN}|" .env
msg_ok "Created InfluxDB read-only token"

msg_info "Starting SOLECTRUS"
$STD docker compose up -d
msg_ok "Started SOLECTRUS"

# Save credentials
cat > "${INSTALL_DIR}/.credentials" <<CREDS
SOLECTRUS Credentials (generated $(date +%Y-%m-%d))
====================================================
Dashboard URL:     http://${CT_IP}:3000
Admin Password:    ${ADMIN_PW}
Postgres Password: ${POSTGRES_PW}
InfluxDB Password: ${INFLUX_PW}
InfluxDB Admin Token: ${INFLUX_ADMIN_TOKEN}
InfluxDB Read Token:  ${INFLUX_READ_TOKEN}
====================================================
CREDS
chmod 600 "${INSTALL_DIR}/.credentials"

motd_ssh
customize
cleanup_lxc
