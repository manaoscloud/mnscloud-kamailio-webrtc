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
    debian:bookworm|debian:trixie)
      ok "Supported OS detected: $PRETTY_NAME"
      ;;
    *)
      die "Unsupported OS: ${PRETTY_NAME:-unknown}. Supported: Debian 12 and Debian 13."
      ;;
  esac
}

install_base_packages() {
  run apt-get update -y
  run apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release jq uuid-runtime \
    nginx openssl dnsutils netcat-openbsd
}

install_kamailio_repository() {
  local repo_codename="$OS_CODENAME"

  case "$OS_ID:$repo_codename" in
    debian:bookworm|debian:trixie) ;;
    *) die "Kamailio repository is supported only on Debian 12 and Debian 13." ;;
  esac

  install -d -m 0755 /usr/share/keyrings
  run rm -f /usr/share/keyrings/kamailio.gpg.tmp
  run curl -fsSL -o /usr/share/keyrings/kamailio.asc.tmp https://deb.kamailio.org/kamailiodebkey.gpg
  run gpg --batch --yes --dearmor -o /usr/share/keyrings/kamailio.gpg.tmp /usr/share/keyrings/kamailio.asc.tmp
  run rm -f /usr/share/keyrings/kamailio.asc.tmp
  run mv /usr/share/keyrings/kamailio.gpg.tmp /usr/share/keyrings/kamailio.gpg
  run chmod 0644 /usr/share/keyrings/kamailio.gpg

  write_file "/etc/apt/sources.list.d/kamailio.list" "0644" <<EOF
deb [signed-by=/usr/share/keyrings/kamailio.gpg] http://deb.kamailio.org/kamailio61 ${repo_codename} main
EOF

  write_file "/etc/apt/preferences.d/kamailio" "0644" <<'EOF'
Package: kamailio*
Pin: origin deb.kamailio.org
Pin-Priority: 1001
EOF

  run apt-get update -y
}
