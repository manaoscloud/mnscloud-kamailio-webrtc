#!/usr/bin/env bash
set -Eeuo pipefail

install_systemd_units() {
  install -m 0644 "$REPO_DIR/config/systemd/mnscloud-webrtc-sync.service.template" \
    /etc/systemd/system/mnscloud-webrtc-sync.service
  install -m 0644 "$REPO_DIR/config/systemd/mnscloud-webrtc-sync.timer.template" \
    /etc/systemd/system/mnscloud-webrtc-sync.timer
  install -m 0644 "$REPO_DIR/config/systemd/mnscloud-webrtc-acme.service.template" \
    /etc/systemd/system/mnscloud-webrtc-acme.service
  systemctl daemon-reload
  systemctl enable --now mnscloud-webrtc-sync.timer
}

# Updates run both from the MNSCloud Agent (unconfined) and from the sync timer (ProtectSystem=full,
# /etc read-only): only an unconfined run can refresh the units, which it does when they changed.
refresh_systemd_units_if_changed() {
  local unit target
  [[ -f /etc/systemd/system/mnscloud-webrtc-sync.service ]] || return 0
  for unit in mnscloud-webrtc-sync.service mnscloud-webrtc-sync.timer mnscloud-webrtc-acme.service; do
    target="/etc/systemd/system/$unit"
    [[ -f "$target" ]] && cmp -s "$REPO_DIR/config/systemd/$unit.template" "$target" && continue
    if [[ ! -w /etc/systemd/system ]] || ! touch "$target" 2>/dev/null; then
      warn "Systemd unit $unit is outdated; the next MNSCloud Agent update refreshes it."
      return 0
    fi
    install_systemd_units
    ok "Systemd units refreshed."
    return 0
  done
}

enable_services() {
  run systemctl enable --now nginx
  run systemctl enable --now kamailio
}
