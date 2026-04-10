#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: ledermann (Georg Ledermann)
# License: MIT | https://github.com/solectrus/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/solectrus/solectrus

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

SOLECTRUS_URL="https://raw.githubusercontent.com/solectrus/solectrus/refs/heads/main"
INSTALL_DIR="/opt/solectrus"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  jq
msg_ok "Installed Dependencies"

setup_docker

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
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')
INFLUX_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')
INFLUX_ADMIN_TOKEN=$(openssl rand -base64 48 | tr -d '/+=')
SECRET_KEY_BASE=$(openssl rand -hex 64)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')

# Resolve non-secret values for later reference
INFLUX_USERNAME=$(grep -m1 '^INFLUX_USERNAME=' .env | cut -d= -f2-)
INFLUX_PORT=$(grep -m1 '^INFLUX_PORT=' .env | cut -d= -f2-)
INFLUX_ORG=$(grep -m1 '^INFLUX_ORG=' .env | cut -d= -f2-)
INFLUX_BUCKET=$(grep -m1 '^INFLUX_BUCKET=' .env | cut -d= -f2-)

# Replace default values in .env with generated credentials and absolute paths
sed -i \
  -e "s|^DB_VOLUME_PATH=.*|DB_VOLUME_PATH=${INSTALL_DIR}/postgresql|" \
  -e "s|^INFLUX_VOLUME_PATH=.*|INFLUX_VOLUME_PATH=${INSTALL_DIR}/influxdb|" \
  -e "s|^REDIS_VOLUME_PATH=.*|REDIS_VOLUME_PATH=${INSTALL_DIR}/redis|" \
  -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
  -e "s|^INFLUX_PASSWORD=.*|INFLUX_PASSWORD=${INFLUX_PASSWORD}|" \
  -e "s|^INFLUX_ADMIN_TOKEN=.*|INFLUX_ADMIN_TOKEN=${INFLUX_ADMIN_TOKEN}|" \
  -e "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=${SECRET_KEY_BASE}|" \
  -e "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASSWORD}|" \
  -e "s|^APP_HOST=.*|APP_HOST=${LOCAL_IP}|" \
  -e "s|^INSTALLATION_DATE=.*|INSTALLATION_DATE=$(date +%Y-%m-%d)|" \
  .env

# Verify that all critical variables were replaced
for var in POSTGRES_PASSWORD INFLUX_PASSWORD INFLUX_ADMIN_TOKEN SECRET_KEY_BASE ADMIN_PASSWORD APP_HOST; do
  if ! grep -q "^${var}=.\+" .env; then
    msg_error "Failed to set ${var} in .env (variable not found in template)"
    exit 1
  fi
done

msg_ok "Setup SOLECTRUS"

# Start InfluxDB first to create dedicated least-privilege tokens via its API
msg_info "Starting InfluxDB"
$STD docker compose up -d influxdb
for i in {1..30}; do
  curl -sf http://localhost:${INFLUX_PORT}/ping >/dev/null 2>&1 && break
  sleep 2
done
if [[ $i -eq 30 ]] && ! curl -sf http://localhost:${INFLUX_PORT}/ping >/dev/null 2>&1; then
  msg_error "InfluxDB failed to start within 60 seconds"
  exit 1
fi
msg_ok "Started InfluxDB"

msg_info "Creating InfluxDB tokens"
ORG_ID=$(curl -sf http://localhost:${INFLUX_PORT}/api/v2/orgs \
  -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" | jq -r '.orgs[0].id')
if [[ -z "$ORG_ID" || "$ORG_ID" == "null" ]]; then
  msg_error "Failed to retrieve InfluxDB organization ID"
  exit 1
fi

create_influx_token() {
  local description=$1 action=$2
  curl -sf http://localhost:${INFLUX_PORT}/api/v2/authorizations \
    -H "Authorization: Token ${INFLUX_ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"description\":\"${description}\",\"orgID\":\"${ORG_ID}\",\"permissions\":[{\"action\":\"${action}\",\"resource\":{\"type\":\"buckets\",\"orgID\":\"${ORG_ID}\"}}]}" \
    | jq -r '.token'
}

INFLUX_READ_TOKEN=$(create_influx_token "SOLECTRUS read-only" "read")
if [[ -z "$INFLUX_READ_TOKEN" || "$INFLUX_READ_TOKEN" == "null" ]]; then
  msg_error "Failed to create InfluxDB read-only token"
  exit 1
fi

INFLUX_WRITE_TOKEN=$(create_influx_token "SOLECTRUS write" "write")
if [[ -z "$INFLUX_WRITE_TOKEN" || "$INFLUX_WRITE_TOKEN" == "null" ]]; then
  msg_error "Failed to create InfluxDB write token"
  exit 1
fi

if grep -q "^INFLUX_TOKEN_READ=" .env; then
  sed -i "s|^INFLUX_TOKEN_READ=.*|INFLUX_TOKEN_READ=${INFLUX_READ_TOKEN}|" .env
else
  echo "INFLUX_TOKEN_READ=${INFLUX_READ_TOKEN}" >> .env
fi
if grep -q "^INFLUX_TOKEN_WRITE=" .env; then
  sed -i "s|^INFLUX_TOKEN_WRITE=.*|INFLUX_TOKEN_WRITE=${INFLUX_WRITE_TOKEN}|" .env
else
  echo "INFLUX_TOKEN_WRITE=${INFLUX_WRITE_TOKEN}" >> .env
fi
msg_ok "Created InfluxDB tokens"

msg_info "Starting SOLECTRUS"
$STD docker compose up -d
msg_ok "Started SOLECTRUS"

{
  echo "========================================"
  echo "  SOLECTRUS Credentials"
  echo "========================================"
  echo ""
  echo "--- Dashboard ---"
  echo "  URL:            http://${LOCAL_IP}:3000"
  echo "  Admin Password: ${ADMIN_PASSWORD}"
  echo ""
  echo "--- InfluxDB ---"
  echo "  URL:            http://${LOCAL_IP}:${INFLUX_PORT}"
  echo "  Organization:   ${INFLUX_ORG}"
  echo "  Bucket:         ${INFLUX_BUCKET}"
  echo "  Username:       ${INFLUX_USERNAME}"
  echo "  Password:       ${INFLUX_PASSWORD}"
  echo "  Admin Token:    ${INFLUX_ADMIN_TOKEN}"
  echo "  Read Token:     ${INFLUX_READ_TOKEN}"
  echo "  Write Token:    ${INFLUX_WRITE_TOKEN}"
} > ~/solectrus.creds
chmod 600 ~/solectrus.creds

motd_ssh
customize
cleanup_lxc
