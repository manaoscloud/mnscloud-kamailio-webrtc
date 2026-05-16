#!/usr/bin/env bash
set -Eeuo pipefail

render_nginx_config() {
  local server_name="${1:-_}"
  sed "s/{{SERVER_NAME}}/$server_name/g" \
    "$REPO_DIR/config/nginx/mnscloud-webrtc.conf.template" \
    > /etc/nginx/sites-available/mnscloud-webrtc.conf
  ln -sf /etc/nginx/sites-available/mnscloud-webrtc.conf /etc/nginx/sites-enabled/mnscloud-webrtc.conf
  rm -f /etc/nginx/sites-enabled/default
}

validate_nginx() {
  run nginx -t
}

