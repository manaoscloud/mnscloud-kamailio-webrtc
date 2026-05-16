#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_DIR/scripts/lib/common.sh"

require_root

systemctl disable --now mnscloud-webrtc-sync.timer 2>/dev/null || true
systemctl stop mnscloud-webrtc-sync.service 2>/dev/null || true
rm -f /etc/systemd/system/mnscloud-webrtc-sync.service
rm -f /etc/systemd/system/mnscloud-webrtc-sync.timer
systemctl daemon-reload

warn "Service packages were not removed."
warn "Configuration was kept under $CONFIG_DIR for audit and recovery."
ok "MNSCloud Kamailio WebRTC Edge units removed."

