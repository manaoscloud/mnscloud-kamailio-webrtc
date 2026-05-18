#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="mnscloud-kamailio-webrtc"
INSTALL_DIR="/opt/mnscloud/kamailio-webrtc"
CONFIG_DIR="/etc/mnscloud/kamailio-webrtc"
STATE_DIR="/var/lib/mnscloud/kamailio-webrtc"
LOG_DIR="/var/log/mnscloud/kamailio-webrtc"
KAMAILIO_MNS_DIR="/etc/kamailio/mnscloud"

log() {
  printf '[%s] %s %s\n' "$APP_NAME" "$1" "$2"
}

info() {
  log "INFO" "$*"
}

ok() {
  log "OK" "$*"
}

warn() {
  log "WARN" "$*" >&2
}

die() {
  log "ERROR" "$*" >&2
  exit 1
}

run() {
  info "RUN: $*"
  "$@"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must be run as root."
  fi
}

write_file() {
  local path="$1"
  local mode="$2"
  local owner="${3:-root:root}"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  install -D -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$tmp" "$path"
  rm -f "$tmp"
  ok "File updated: $path"
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local value
  read -r -p "$prompt [$default]: " value
  printf '%s' "${value:-$default}"
}

prompt_optional() {
  local prompt="$1"
  local value
  read -r -p "$prompt: " value
  printf '%s' "$value"
}

ensure_uuid_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    if command -v uuidgen >/dev/null 2>&1; then
      uuidgen > "$path"
    else
      cat /proc/sys/kernel/random/uuid > "$path"
    fi
    chmod 0600 "$path"
  fi
}

install_payload() {
  local source_dir="$1"

  install -d -m 0755 "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/scripts" "$INSTALL_DIR/config" "$INSTALL_DIR/docs"
  cp -a "$source_dir/scripts" "$source_dir/config" "$source_dir/docs" "$INSTALL_DIR/"
  install -m 0644 "$source_dir/README.md" "$INSTALL_DIR/README.md"
  install -m 0644 "$source_dir/SECURITY.md" "$INSTALL_DIR/SECURITY.md"
  install -m 0644 "$source_dir/SKILL.md" "$INSTALL_DIR/SKILL.md"
  chmod 0755 "$INSTALL_DIR/scripts/"*.sh
  ok "Runtime payload installed in $INSTALL_DIR"
}
