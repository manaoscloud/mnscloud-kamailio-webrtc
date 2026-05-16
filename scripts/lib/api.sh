#!/usr/bin/env bash
set -Eeuo pipefail

save_api_base() {
  local api_base="$1"
  printf '%s\n' "$api_base" > "$CONFIG_DIR/api.base"
  chmod 0600 "$CONFIG_DIR/api.base"
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
    -H "X-Node-UUID: $uuid" \
    "$base/api/v1/webrtc/edge/config" \
    -o "$output"
  jq type "$output" >/dev/null
}

