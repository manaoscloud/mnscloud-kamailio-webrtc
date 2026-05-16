#!/usr/bin/env bash
set -Eeuo pipefail

install_rtpengine() {
  run apt-get install -y --no-install-recommends rtpengine
}

render_rtpengine_config() {
  install -m 0644 "$REPO_DIR/config/rtpengine/rtpengine.conf.template" /etc/rtpengine/rtpengine.conf
}

