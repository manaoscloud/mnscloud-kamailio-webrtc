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
  info "Register this UUID in MNSCloud with engine kamailio before continuing."

  local api_base server_name node_token_value
  api_base="$(prompt_default "MNSCloud API base URL" "https://api.example.com")"
  server_name="$(prompt_default "WebRTC edge public domain" "webrtc.example.com")"
  node_token_value="$(prompt_required "WebRTC node token generated in MNSCloud")"

  save_api_base "$api_base"
  save_node_token "$node_token_value"
  install_payload "$SOURCE_DIR"
  REPO_DIR="$INSTALL_DIR"

  install_base_packages
  validate_edge_registration "kamailio"
  install_kamailio
  install_rtpengine

  render_nginx_config "$server_name"
  render_kamailio_config
  render_rtpengine_config "$server_name"
  install_systemd_units

  bootstrap_edge_node "$server_name"

  validate_nginx
  validate_kamailio
  enable_services

  ok "MNSCloud Kamailio WebRTC Edge installed."
  info "Node UUID: $(node_uuid)"
  info "Cyber Security is applied separately through MNSCloud Agent using the WebRTC Edge profile."
}

main "$@"
