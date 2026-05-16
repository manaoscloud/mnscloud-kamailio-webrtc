#!/usr/bin/env bash
set -Eeuo pipefail

health_check() {
  validate_nginx
  validate_kamailio
  systemctl is-active --quiet nginx || die "nginx is not active."
  systemctl is-active --quiet kamailio || die "kamailio is not active."
  systemctl is-active --quiet rtpengine || die "rtpengine is not active."
  ok "Core services are active."
}

