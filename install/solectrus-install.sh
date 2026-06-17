#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: ledermann (Georg Ledermann)
# License: MIT | https://github.com/solectrus/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/solectrus

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

HELIOS_BOOTSTRAP="https://raw.githubusercontent.com/solectrus/helios/main/bootstrap/install.sh"
INSTALL_DIR="/opt/solectrus"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  openssl
msg_ok "Installed Dependencies"

setup_docker

# SOLECTRUS is deployed through HELIOS, a configuration manager that installs,
# configures and manages the full SOLECTRUS stack (Dashboard, PostgreSQL,
# InfluxDB, Redis, collectors) from its web interface. We delegate to the
# upstream HELIOS bootstrap installer so this stays a single source of truth.
#
# The bootstrap installs into the current directory, so we run it from
# INSTALL_DIR. The HELIOS_* env vars drive its unattended mode:
#   HELIOS_ASSUME_YES     auto-confirm operational prompts (Docker is already
#                         installed above, so it is only a safety net)
#   HELIOS_ACCEPT_LICENSE accept the HELIOS license non-interactively
#   HELIOS_QUIET          silence docker compose pull/up output
msg_info "Setup HELIOS"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

curl -fsSL "$HELIOS_BOOTSTRAP" -o /tmp/helios-install.sh || {
  msg_error "Failed to download HELIOS bootstrap installer"
  exit 1
}

export HELIOS_ASSUME_YES=1 HELIOS_ACCEPT_LICENSE=1 HELIOS_QUIET=1
$STD bash /tmp/helios-install.sh
rm -f /tmp/helios-install.sh
msg_ok "Setup HELIOS"

# The bootstrap generated the admin password into .env; surface it for the user.
ADMIN_PASSWORD=$(grep -m1 '^ADMIN_PASSWORD=' "${INSTALL_DIR}/.env" | cut -d= -f2-)

{
  echo "========================================"
  echo "  HELIOS Credentials"
  echo "========================================"
  echo ""
  echo "  HELIOS URL:     http://${LOCAL_IP}:3999"
  echo "  Admin Password: ${ADMIN_PASSWORD}"
  echo ""
  echo "Open the HELIOS web interface to configure and start"
  echo "your SOLECTRUS dashboard and data collectors."
} >~/solectrus.creds
chmod 600 ~/solectrus.creds

motd_ssh
customize
cleanup_lxc
