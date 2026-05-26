#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$SOURCE_DIR"
API_BASE="${MNSCLOUD_API_BASE:-}"
PUBLIC_DOMAIN="${MNSCLOUD_WEBRTC_PUBLIC_DOMAIN:-}"
NODE_UUID="${MNSCLOUD_WEBRTC_NODE_UUID:-}"
RUNTIME_TOKEN="${MNSCLOUD_WEBRTC_RUNTIME_TOKEN:-}"

usage() {
  cat <<'TXT'
Usage:
  scripts/install-kamailio-webrtc.sh [--api-base URL] [--public-domain DOMAIN] [--node-uuid UUID] [--runtime-token TOKEN]

Installs the native MNSCloud Kamailio WebRTC edge runtime.
TXT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-base)
      API_BASE="${2:-}"
      shift 2
      ;;
    --public-domain)
      PUBLIC_DOMAIN="${2:-}"
      shift 2
      ;;
    --node-uuid)
      NODE_UUID="${2:-}"
      shift 2
      ;;
    --runtime-token)
      RUNTIME_TOKEN="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[mnscloud-kamailio-webrtc] unsupported option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

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
  save_node_uuid "$NODE_UUID"
  ensure_uuid_file "$CONFIG_DIR/node.uuid"
  info "Node UUID: $(node_uuid)"
  if ! systemctl is-active --quiet mnscloud-agent; then
    die "mnscloud-agent must be installed, enrolled, and active before installing the WebRTC edge."
  fi

  local api_base server_name
  api_base="${API_BASE:-$(prompt_default "MNSCloud API base URL" "https://api.example.com")}"
  server_name="${PUBLIC_DOMAIN:-$(prompt_default "WebRTC edge public domain" "webrtc.example.com")}"

  save_api_base "$api_base"
  save_public_domain "$server_name"
  save_runtime_token "$RUNTIME_TOKEN"
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
  if [[ -x /opt/mnscloud/mnscloud-agent/scripts/update-agent.sh ]]; then
    info "Refreshing MNSCloud Agent capabilities after WebRTC runtime install."
    bash /opt/mnscloud/mnscloud-agent/scripts/update-agent.sh \
      --api-base "$api_base" \
      --install-label "$(hostname -f 2>/dev/null || hostname)"
  else
    warn "MNSCloud Agent source repo not found at /opt/mnscloud/mnscloud-agent; restart or update the Agent manually so it reports webrtc.kamailio.manage."
  fi

  ok "MNSCloud Kamailio WebRTC Edge installed."
  info "Node UUID: $(node_uuid)"
  info "Assign this server to the active MNSCloud Agent and provision edge sync from the platform."
}

main "$@"
