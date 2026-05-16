#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/api.sh"
. "$REPO_DIR/scripts/lib/kamailio.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"

require_root
install -d -m 0700 "$CONFIG_DIR" "$STATE_DIR"

CONFIG_TMP="$(mktemp)"
trap 'rm -f "$CONFIG_TMP"' EXIT

fetch_edge_config "$CONFIG_TMP"
install -m 0600 "$CONFIG_TMP" "$CONFIG_DIR/config.json"

render_kamailio_config
validate_kamailio
systemctl reload kamailio || systemctl restart kamailio
ok "WebRTC edge configuration synchronized."

