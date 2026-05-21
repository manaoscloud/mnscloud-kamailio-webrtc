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
  install_nginx_org_repository

  run apt-get update -y
  apt_install \
    ca-certificates curl gnupg lsb-release jq uuid-runtime \
    nginx openssl dnsutils iproute2 netcat-openbsd
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive run apt-get install -y --no-install-recommends \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    "$@"
}

install_nginx_org_repository() {
  run apt-get update -y
  apt_install curl gnupg2 ca-certificates lsb-release debian-archive-keyring

  install -d -m 0755 /usr/share/keyrings
  run rm -f /usr/share/keyrings/nginx-archive-keyring.gpg.tmp
  run curl -fsSL -o /usr/share/keyrings/nginx_signing.key.tmp https://nginx.org/keys/nginx_signing.key
  run gpg --batch --yes --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg.tmp /usr/share/keyrings/nginx_signing.key.tmp
  run rm -f /usr/share/keyrings/nginx_signing.key.tmp
  run mv /usr/share/keyrings/nginx-archive-keyring.gpg.tmp /usr/share/keyrings/nginx-archive-keyring.gpg
  run chmod 0644 /usr/share/keyrings/nginx-archive-keyring.gpg

  local repo_codename="${OS_CODENAME:-}"
  if [[ -z "$repo_codename" ]]; then
    repo_codename="$(lsb_release -cs)"
  fi

  write_file "/etc/apt/sources.list.d/nginx.list" "0644" <<EOF
deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian ${repo_codename} nginx
EOF

  write_file "/etc/apt/preferences.d/99nginx" "0644" <<'EOF'
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF
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
