#!/usr/bin/env bash
set -Eeuo pipefail

save_api_base() {
  local api_base="$1"
  api_base="${api_base%/}"
  printf '%s\n' "$api_base" > "$CONFIG_DIR/api.base"
  chmod 0600 "$CONFIG_DIR/api.base"
}

save_node_token() {
  local token="$1"
  [[ -n "$token" ]] || return 0
  printf '%s\n' "$token" > "$CONFIG_DIR/node.token"
  chmod 0600 "$CONFIG_DIR/node.token"
}

api_base() {
  [[ -s "$CONFIG_DIR/api.base" ]] || die "API base is not configured."
  tr -d '\r\n' < "$CONFIG_DIR/api.base"
}

node_uuid() {
  [[ -s "$CONFIG_DIR/node.uuid" ]] || die "Node UUID is not configured."
  tr -d '\r\n' < "$CONFIG_DIR/node.uuid"
}

node_token() {
  [[ -s "$CONFIG_DIR/node.token" ]] || die "Node token is not configured. Register this node in MNSCloud first."
  tr -d '\r\n' < "$CONFIG_DIR/node.token"
}

fetch_edge_config() {
  local output="$1"
  local base token uuid
  base="$(api_base)"
  token="$(node_token)"
  uuid="$(node_uuid)"
  run curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    "$base/api/v1/webrtc/edge/config" \
    -o "$output"
  jq type "$output" >/dev/null
}

bootstrap_edge_node() {
  local base token uuid hostname public_domain output payload
  base="$(api_base)"
  token="$(node_token)"
  uuid="$(node_uuid)"
  hostname="$(hostname -f 2>/dev/null || hostname)"
  public_domain="${1:-}"
  output="$(mktemp)"
  payload="$(mktemp)"
  jq -n \
    --arg node_uuid "$uuid" \
    --arg hostname "$hostname" \
    --arg publicDomain "$public_domain" \
    '{node_uuid:$node_uuid, hostname:$hostname, publicDomain:$publicDomain}' > "$payload"

  run curl -fsSL \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    -H "Content-Type: application/json" \
    --data @"$payload" \
    "$base/api/v1/webrtc/edge/bootstrap" \
    -o "$output"
  jq type "$output" >/dev/null
  rm -f "$output" "$payload"
  ok "WebRTC edge node validated against MNSCloud API."
}
