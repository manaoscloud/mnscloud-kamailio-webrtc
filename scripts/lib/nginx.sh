#!/usr/bin/env bash
set -Eeuo pipefail

render_nginx_config() {
  local server_name="${1:-_}"
  install -d -m 0755 /etc/nginx/conf.d
  sed "s/{{SERVER_NAME}}/$server_name/g" \
    "$REPO_DIR/config/nginx/mnscloud-webrtc.conf.template" \
    > /etc/nginx/conf.d/mnscloud-webrtc.conf
  rm -f /etc/nginx/conf.d/default.conf
}

validate_nginx() {
  run nginx -t
}
