#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$SOURCE_DIR"

# shellcheck source=scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/os.sh"
. "$REPO_DIR/scripts/lib/api.sh"
. "$REPO_DIR/scripts/lib/kamailio.sh"
. "$REPO_DIR/scripts/lib/rtpengine.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"
. "$REPO_DIR/scripts/lib/systemd.sh"
. "$REPO_DIR/scripts/lib/validation.sh"

main() {
  require_root
  require_supported_os

  install -d -m 0700 "$CONFIG_DIR" "$STATE_DIR" "$LOG_DIR"
  ensure_uuid_file "$CONFIG_DIR/node.uuid"
  info "Node UUID: $(node_uuid)"
  if ! systemctl is-active --quiet mnscloud-agent; then
    die "mnscloud-agent must be installed, enrolled, and active before installing the WebRTC edge."
  fi

  local api_base server_name
  api_base="$(prompt_default "MNSCloud API base URL" "https://api.example.com")"
  server_name="$(prompt_default "WebRTC edge public domain" "webrtc.example.com")"

  save_api_base "$api_base"
  save_public_domain "$server_name"
  install_payload "$SOURCE_DIR"
  REPO_DIR="$INSTALL_DIR"

  install_base_packages
  install_kamailio
  install_rtpengine

  render_nginx_config "$server_name"
  render_kamailio_config
  render_rtpengine_config "$server_name"
  install_systemd_units

  validate_nginx
  validate_kamailio
  enable_services

  ok "MNSCloud Kamailio WebRTC Edge installed."
  info "Node UUID: $(node_uuid)"
  info "Assign this server to the active MNSCloud Agent and provision edge sync from the platform."
}

main "$@"
