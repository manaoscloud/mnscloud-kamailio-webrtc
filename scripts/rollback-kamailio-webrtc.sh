#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/api.sh
. "$REPO_DIR/scripts/lib/api.sh"
# shellcheck source=scripts/lib/kamailio.sh
. "$REPO_DIR/scripts/lib/kamailio.sh"
# shellcheck source=scripts/lib/nginx.sh
. "$REPO_DIR/scripts/lib/nginx.sh"
# shellcheck source=scripts/lib/validation.sh
. "$REPO_DIR/scripts/lib/validation.sh"

usage() {
  cat <<'TXT'
Usage:
  sudo ./scripts/rollback-kamailio-webrtc.sh --ref <known-good-git-ref>

Rolls the local WebRTC edge runtime back to an explicit Git tag or commit,
syncs generated configuration from the API, and validates Nginx and Kamailio.
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

[[ -n "$REF" ]] || { usage; exit 1; }
require_root

cd "$REPO_DIR"
git fetch --tags --prune origin
if ! git rev-parse --verify --quiet "${REF}^{commit}" >/dev/null; then
  recent_refs="$(git tag --sort=-creatordate | head -10 | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  [[ -n "$recent_refs" ]] || recent_refs="none"
  die "rollback ref not found: ${REF}. Recent tags: ${recent_refs}"
fi

git checkout --detach "$REF"
install_payload "$REPO_DIR"

server_name="_"
if [[ -s "$CONFIG_DIR/public.domain" ]]; then
  server_name="$(tr -d '\r\n' < "$CONFIG_DIR/public.domain")"
fi

CONFIG_TMP="$(mktemp)"
trap 'rm -f "$CONFIG_TMP"' EXIT

fetch_edge_config "$CONFIG_TMP"
install -m 0600 "$CONFIG_TMP" "$CONFIG_DIR/config.json"

render_nginx_config "$server_name"
render_kamailio_config

validate_nginx
validate_kamailio
run systemctl reload nginx
run systemctl restart kamailio
health_check
bootstrap_edge "$server_name"

ok "MNSCloud Kamailio WebRTC Edge rollback completed: $REF"
