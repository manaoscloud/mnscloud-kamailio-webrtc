#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/api.sh"
. "$REPO_DIR/scripts/lib/kamailio.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"

usage() {
  cat <<'TXT'
Usage:
  sudo ./scripts/update-kamailio-webrtc.sh [--ref <git-tag-or-commit>]

Updates the local WebRTC edge runtime, syncs generated configuration from the
API, and validates Nginx and Kamailio.
TXT
}

REF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_root
install -d -m 0700 "$CONFIG_DIR" "$STATE_DIR"

runtime_config_hash() {
  local target
  for target in \
    "$CONFIG_DIR/config.json" \
    /etc/kamailio/kamailio.cfg \
    "$KAMAILIO_MNS_DIR" \
    /etc/nginx/conf.d/mnscloud-webrtc.conf; do
    if [[ -f "$target" ]]; then
      sha256sum "$target"
    elif [[ -d "$target" ]]; then
      find "$target" -type f -print0 2>/dev/null |
        sort -z |
        xargs -0 sha256sum 2>/dev/null || true
    fi
  done | sha256sum | awk '{ print $1 }'
}

runtime_nginx_hash() {
  if [[ -f /etc/nginx/conf.d/mnscloud-webrtc.conf ]]; then
    sha256sum /etc/nginx/conf.d/mnscloud-webrtc.conf | awk '{ print $1 }'
    return 0
  fi
  printf '%s\n' 'missing'
}

runtime_kamailio_hash() {
  local target
  for target in /etc/kamailio/kamailio.cfg "$KAMAILIO_MNS_DIR"; do
    if [[ -f "$target" ]]; then
      sha256sum "$target"
    elif [[ -d "$target" ]]; then
      find "$target" -type f -print0 2>/dev/null |
        sort -z |
        xargs -0 sha256sum 2>/dev/null || true
    fi
  done | sha256sum | awk '{ print $1 }'
}

if [[ -n "$REF" ]]; then
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    die "--ref can only be used from a git checkout. Run the installed payload without --ref."
  fi
  cd "$REPO_DIR"
  git fetch --tags --prune origin
  if ! git rev-parse --verify --quiet "${REF}^{commit}" >/dev/null; then
    recent_refs="$(git tag --sort=-creatordate | head -10 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    [[ -n "$recent_refs" ]] || recent_refs="none"
    die "update ref not found: ${REF}. Recent tags: ${recent_refs}"
  fi
  git checkout --detach "$REF"
fi

if [[ "$(realpath -m "$REPO_DIR")" != "$(realpath -m "$INSTALL_DIR")" ]]; then
  install_payload "$REPO_DIR"
  exec "$INSTALL_DIR/scripts/update-kamailio-webrtc.sh"
fi

CONFIG_BEFORE_HASH="$(runtime_config_hash)"
NGINX_BEFORE_HASH="$(runtime_nginx_hash)"
KAMAILIO_BEFORE_HASH="$(runtime_kamailio_hash)"
FORCE_SERVICE_RESTART="false"
if [[ -n "$REF" ]]; then
  FORCE_SERVICE_RESTART="true"
fi

CONFIG_TMP="$(mktemp)"
trap 'rm -f "$CONFIG_TMP"' EXIT

fetch_edge_config "$CONFIG_TMP"
install -m 0600 "$CONFIG_TMP" "$CONFIG_DIR/config.json"

server_name="_"
if [[ -s "$CONFIG_DIR/public.domain" ]]; then
  server_name="$(tr -d '\r\n' < "$CONFIG_DIR/public.domain")"
fi

render_nginx_config "$server_name"
render_kamailio_config
validate_nginx
validate_kamailio
CONFIG_AFTER_HASH="$(runtime_config_hash)"
NGINX_AFTER_HASH="$(runtime_nginx_hash)"
KAMAILIO_AFTER_HASH="$(runtime_kamailio_hash)"

if [[ "$NGINX_BEFORE_HASH" != "$NGINX_AFTER_HASH" || "$FORCE_SERVICE_RESTART" == "true" ]]; then
  run systemctl reload nginx
else
  ok "Nginx WebRTC configuration unchanged; reload skipped."
fi

if [[ "$KAMAILIO_BEFORE_HASH" != "$KAMAILIO_AFTER_HASH" || "$FORCE_SERVICE_RESTART" == "true" ]]; then
  run systemctl restart kamailio
else
  ok "Kamailio WebRTC configuration unchanged; restart skipped to preserve active SIP/WebSocket dialogs."
fi
bootstrap_edge "$server_name"
if [[ "$CONFIG_BEFORE_HASH" == "$CONFIG_AFTER_HASH" && "$FORCE_SERVICE_RESTART" != "true" ]]; then
  ok "WebRTC edge configuration already synchronized."
else
  ok "WebRTC edge configuration synchronized."
fi
