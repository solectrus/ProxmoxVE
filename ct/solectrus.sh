#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/solectrus/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 Georg Ledermann
# Author: Georg Ledermann
# License: MIT | https://github.com/solectrus/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/solectrus/solectrus

APP="SOLECTRUS"
var_tags="${var_tags:-docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  [[ -d /opt/solectrus ]] || {
    msg_error "No ${APP} Installation Found!"
    exit 1
  }

  msg_info "Updating SOLECTRUS"
  cd /opt/solectrus
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated SOLECTRUS"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
