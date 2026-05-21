#!/usr/bin/env bash
set -Eeuo pipefail

install_rtpengine() {
  install_rtpengine_kernel_headers
  apt_install rtpengine
}

install_rtpengine_kernel_headers() {
  local headers_package="linux-headers-$(uname -r)"

  if dpkg-query -W -f='${Status}' "$headers_package" 2>/dev/null | grep -q "install ok installed"; then
    ok "Kernel headers already installed: $headers_package"
    return 0
  fi

  if apt-cache show "$headers_package" >/dev/null 2>&1; then
    info "Installing kernel headers for rtpengine DKMS: $headers_package"
    apt_install "$headers_package"
    return 0
  fi

  warn "Kernel headers package not available: $headers_package"
  warn "rtpengine will install, but kernel forwarding may stay disabled until matching headers are available."
}

render_rtpengine_config() {
  install -m 0644 "$REPO_DIR/config/rtpengine/rtpengine.conf.template" /etc/rtpengine/rtpengine.conf
}
