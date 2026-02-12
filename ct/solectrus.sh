#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/solectrus/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 Georg Ledermann
# Author: Georg Ledermann
# License: MIT | https://github.com/solectrus/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/solectrus/solectrus

# -- Default container settings -----------------------------------------------
APP="SOLECTRUS"
var_tags="${var_tags:-docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

# -- Initialization ------------------------------------------------------------
header_info "$APP"
variables
color
catch_errors

# -- Update (called when container already exists) -----------------------------
function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/solectrus ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating OS"
  $STD apt-get update
  $STD apt-get -y upgrade
  msg_ok "Updated OS"

  msg_info "Updating ${APP}"
  cd /opt/solectrus || exit
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated ${APP}"
  exit
}

# -- First-time installation ---------------------------------------------------
start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
echo -e "${INFO}${YW} Credentials stored in ${BGN}~/solectrus.creds${CL}${YW} (inside container ${BL}${CTID}${CL}${YW})${CL}"
