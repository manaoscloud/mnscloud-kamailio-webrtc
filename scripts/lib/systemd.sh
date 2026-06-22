#!/usr/bin/env bash
set -Eeuo pipefail

install_systemd_units() {
  install -m 0644 "$REPO_DIR/config/systemd/mnscloud-webrtc-sync.service.template" \
    /etc/systemd/system/mnscloud-webrtc-sync.service
  install -m 0644 "$REPO_DIR/config/systemd/mnscloud-webrtc-sync.timer.template" \
    /etc/systemd/system/mnscloud-webrtc-sync.timer
  systemctl daemon-reload
  systemctl enable --now mnscloud-webrtc-sync.timer
}

enable_services() {
  run systemctl enable --now nginx
  run systemctl enable --now kamailio
}
