#!/usr/bin/env bash
set -Eeuo pipefail

install_kamailio() {
  install_kamailio_repository
  apt_install \
    kamailio kamailio-websocket-modules kamailio-tls-modules \
    kamailio-json-modules kamailio-utils-modules kamailio-extra-modules \
    kamailio-outbound-modules kamailio-presence-modules
}

render_kamailio_config() {
  install -d -m 0755 "$KAMAILIO_MNS_DIR"
  install -m 0644 "$REPO_DIR/config/kamailio/kamailio.cfg.template" /etc/kamailio/kamailio.cfg
  install -m 0644 "$REPO_DIR/config/kamailio/"*.template "$KAMAILIO_MNS_DIR/"
  for file in "$KAMAILIO_MNS_DIR/"*.template; do
    mv "$file" "${file%.template}"
  done
}

validate_kamailio() {
  run kamailio -c -f /etc/kamailio/kamailio.cfg
}
