#!/usr/bin/env bash
set -Eeuo pipefail

detect_os() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_CODENAME="${VERSION_CODENAME:-}"
  OS_VERSION_ID="${VERSION_ID:-}"
}

require_supported_os() {
  detect_os
  case "$OS_ID:$OS_CODENAME" in
    debian:bookworm|ubuntu:jammy|ubuntu:noble)
      ok "Supported OS detected: $PRETTY_NAME"
      ;;
    *)
      die "Unsupported OS: ${PRETTY_NAME:-unknown}. Supported: Debian 12, Ubuntu 22.04, Ubuntu 24.04."
      ;;
  esac
}

install_base_packages() {
  run apt-get update -y
  run apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release jq uuid-runtime \
    nginx openssl dnsutils netcat-openbsd
}

