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
  local public_domain="${1:-}"
  local interface_spec
  local tmp
  interface_spec="$(detect_rtpengine_interface "$public_domain")"

  tmp="$(mktemp)"
  sed "s|@RTPENGINE_INTERFACE@|$interface_spec|g" \
    "$REPO_DIR/config/rtpengine/rtpengine.conf.template" > "$tmp"
  install -m 0644 "$tmp" /etc/rtpengine/rtpengine.conf
  rm -f "$tmp"
  ok "rtpengine media interface: $interface_spec"
}

detect_rtpengine_interface() {
  local public_domain="$1"
  local local_ipv4 public_ipv4 local_ipv6 public_ipv6
  local parts=()

  local_ipv4="$(default_route_source_ip 4 || true)"
  public_ipv4="$(resolve_first_ip 4 "$public_domain" || true)"
  local_ipv6="$(default_route_source_ip 6 || true)"
  public_ipv6="$(resolve_first_ip 6 "$public_domain" || true)"

  if [[ -n "$local_ipv4" ]]; then
    if [[ -n "$public_ipv4" && "$public_ipv4" != "$local_ipv4" ]]; then
      parts+=("${local_ipv4}!${public_ipv4}")
    else
      parts+=("$local_ipv4")
    fi
  fi

  if [[ -n "$local_ipv6" ]]; then
    if [[ -n "$public_ipv6" && "$public_ipv6" != "$local_ipv6" ]]; then
      parts+=("${local_ipv6}!${public_ipv6}")
    else
      parts+=("$local_ipv6")
    fi
  fi

  if ((${#parts[@]} == 0)); then
    printf '%s\n' "any"
    return 0
  fi

  local IFS=';'
  printf '%s\n' "${parts[*]}"
}

default_route_source_ip() {
  local family="$1"
  local target

  if [[ "$family" == "4" ]]; then
    target="1.1.1.1"
    ip -o -4 route get "$target" 2>/dev/null | awk '
      {
        for (i = 1; i <= NF; i++) {
          if ($i == "src") {
            print $(i + 1)
            exit
          }
        }
      }'
    return 0
  fi

  target="2001:4860:4860::8888"
  ip -o -6 route get "$target" 2>/dev/null | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == "src") {
          print $(i + 1)
          exit
        }
      }
    }'
}

resolve_first_ip() {
  local family="$1"
  local name="$2"

  [[ -n "$name" ]] || return 0

  if [[ "$family" == "4" ]]; then
    getent ahostsv4 "$name" 2>/dev/null | awk '{ print $1; exit }'
    return 0
  fi

  getent ahostsv6 "$name" 2>/dev/null | awk '{ print $1; exit }'
}
