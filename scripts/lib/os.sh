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
  apt_install \
    ca-certificates curl gnupg lsb-release jq uuid-runtime \
    git openssl dnsutils iproute2 iputils-ping \
    netcat-openbsd ngrep tcpdump traceroute

  load_runtime_kit
  mrtk_install_nginx_package
  export MNSCLOUD_CERTBOT_NGINX_PLUGIN="${MNSCLOUD_CERTBOT_NGINX_PLUGIN:-false}"
  mrtk_ensure_certbot
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive run apt-get install -y --no-install-recommends \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    "$@"
}

resolve_runtime_kit_ref() {
  local kit_dir="$1"
  local channel="$2"
  local manifest ref

  manifest="$(git -C "$kit_dir" show "origin/main:releases/manifest.json" 2>/dev/null)" ||
    die "cannot read runtime kit release manifest from origin/main"
  ref="$(printf '%s\n' "$manifest" | awk -v channel="$channel" '
    $0 ~ "\"" channel "\"" { in_channel = 1; next }
    in_channel && /"ref"[[:space:]]*:/ {
      gsub(/.*"ref"[[:space:]]*:[[:space:]]*"/, "")
      gsub(/".*/, "")
      print
      exit
    }
    in_channel && /^[[:space:]]*}/ { in_channel = 0 }
  ')"
  [[ "$ref" =~ ^v[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]] ||
    die "invalid runtime kit ref for channel ${channel}: ${ref:-empty}"
  printf '%s\n' "$ref"
}

load_runtime_kit() {
  if [[ "${WEBRTC_RUNTIME_KIT_LOADED:-0}" == "1" ]]; then
    return 0
  fi

  local kit_dir="${WEBRTC_RUNTIME_KIT_DIR:-/opt/mnscloud/runtime-kit}"
  local repo_url="${WEBRTC_RUNTIME_KIT_REPO_URL:-https://github.com/manaoscloud/mnscloud-runtime-kit.git}"
  local ref="${WEBRTC_RUNTIME_KIT_REF:-}"
  local channel="${WEBRTC_RUNTIME_KIT_CHANNEL:-stable}"

  if [[ -d "${kit_dir}/.git" ]]; then
    info "Updating runtime kit in ${kit_dir}"
    run git -C "$kit_dir" fetch --all --tags --prune
  else
    info "Installing runtime kit in ${kit_dir}"
    install -d -m 0755 "$(dirname "$kit_dir")"
    run git clone "$repo_url" "$kit_dir"
  fi

  if [[ -z "$ref" ]]; then
    ref="$(resolve_runtime_kit_ref "$kit_dir" "$channel")"
    info "Resolved runtime kit ${channel} channel to ${ref}"
  fi

  run git -C "$kit_dir" -c advice.detachedHead=false checkout "$ref"
  git -C "$kit_dir" pull --ff-only origin "$ref" 2>/dev/null || true
  [[ -r "${kit_dir}/lib/packages.sh" ]] || die "runtime kit packages library not found"

  export MNSCLOUD_RUNTIME_KIT_LOG_PREFIX="mnscloud-kamailio-webrtc/runtime-kit"
  # shellcheck disable=SC1091
  source "${kit_dir}/lib/packages.sh"
  WEBRTC_RUNTIME_KIT_LOADED=1
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
