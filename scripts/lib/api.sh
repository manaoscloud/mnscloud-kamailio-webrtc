#!/usr/bin/env bash
set -Eeuo pipefail

save_api_base() {
  local api_base="$1"
  api_base="${api_base%/}"
  printf '%s\n' "$api_base" > "$CONFIG_DIR/api.base"
  chmod 0600 "$CONFIG_DIR/api.base"
}

save_public_domain() {
  local public_domain="$1"
  [[ -n "$public_domain" ]] || return 0
  printf '%s\n' "$public_domain" > "$CONFIG_DIR/public.domain"
  chmod 0600 "$CONFIG_DIR/public.domain"
}

api_base() {
  [[ -s "$CONFIG_DIR/api.base" ]] || die "API base is not configured."
  tr -d '\r\n' < "$CONFIG_DIR/api.base"
}

node_uuid() {
  [[ -s "$CONFIG_DIR/node.uuid" ]] || die "Node UUID is not configured."
  tr -d '\r\n' < "$CONFIG_DIR/node.uuid"
}

runtime_token() {
  [[ -s "$CONFIG_DIR/runtime.token" ]] || die "WebRTC runtime credential is not configured. Provision this edge through MNSCloud Agent first."
  tr -d '\r\n' < "$CONFIG_DIR/runtime.token"
}

fetch_edge_config() {
  local output="$1"
  local base token uuid
  base="$(api_base)"
  token="$(runtime_token)"
  uuid="$(node_uuid)"
  run curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    "$base/api/v1/webrtc/edge/config" \
    -o "$output"
  jq type "$output" >/dev/null
}

runtime_private_ip() {
  runtime_join_values \
    "$(runtime_default_route_source_ip 4 || true)" \
    "$(runtime_default_route_source_ip 6 || true)"
}

runtime_public_ip() {
  local public_domain="$1"
  runtime_join_values \
    "$(runtime_resolve_first_ip 4 "$public_domain" || true)" \
    "$(runtime_resolve_first_ip 6 "$public_domain" || true)"
}

runtime_edge_version() {
  local kamailio_version
  kamailio_version="$(dpkg-query -W -f='${Version}' kamailio 2>/dev/null || true)"
  if [[ -n "$kamailio_version" ]]; then
    printf 'kamailio:%s\n' "$kamailio_version"
    return 0
  fi
  kamailio -v 2>/dev/null | awk 'NR == 1 { print substr($0, 1, 40); exit }'
}

runtime_default_route_source_ip() {
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

runtime_resolve_first_ip() {
  local family="$1"
  local name="$2"

  [[ -n "$name" ]] || return 0

  if [[ "$family" == "4" ]]; then
    getent ahostsv4 "$name" 2>/dev/null | awk '{ print $1; exit }'
    return 0
  fi

  getent ahostsv6 "$name" 2>/dev/null | awk '{ print $1; exit }'
}

runtime_join_values() {
  local values=()
  local value
  for value in "$@"; do
    [[ -n "$value" ]] || continue
    values+=("$value")
  done
  local IFS=', '
  printf '%s\n' "${values[*]}"
}
