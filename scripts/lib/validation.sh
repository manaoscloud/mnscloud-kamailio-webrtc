#!/usr/bin/env bash
set -Eeuo pipefail

service_is_active() {
  local service="$1"
  systemctl is-active --quiet "$service"
}

require_active_service() {
  local service="$1"
  service_is_active "$service" || die "$service is not active."
  ok "$service is active."
}

require_active_rtpengine() {
  if service_is_active rtpengine || service_is_active rtpengine-daemon; then
    ok "rtpengine is active."
    return 0
  fi
  die "rtpengine is not active."
}

health_check() {
  validate_nginx
  validate_kamailio
  require_active_service nginx
  require_active_service kamailio
  require_active_rtpengine
  ok "Core services are active."
}
