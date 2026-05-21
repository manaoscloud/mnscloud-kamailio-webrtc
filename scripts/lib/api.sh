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

validate_edge_registration() {
  local engine="${1:-kamailio}"
  local base uuid token output payload status
  base="$(api_base)"
  uuid="$(node_uuid)"
  token="$(node_token)"
  output="$(mktemp)"
  payload="$(mktemp)"
  jq -n \
    --arg node_uuid "$uuid" \
    --arg engine "$engine" \
    '{node_uuid:$node_uuid, engine:$engine}' > "$payload"

  status="$(curl -sS -o "$output" -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    -H "X-WebRTC-Engine: $engine" \
    -H "Content-Type: application/json" \
    --data @"$payload" \
    "$base/api/v1/webrtc/edge/validate" || true)"

  if [[ "$status" != 2* ]]; then
    warn "MNSCloud WebRTC edge validation failed."
    jq -r '.error // .message // .' "$output" 2>/dev/null || cat "$output" >&2
    rm -f "$output" "$payload"
    die "Register this node UUID in MNSCloud with engine '$engine' and use a valid token before continuing."
  fi

  jq -e '.status == "success" and .data.registered == true' "$output" >/dev/null
  jq -e '.data.tokenValidated == true' "$output" >/dev/null ||
    die "WebRTC node token was not validated by MNSCloud."
  ok "WebRTC edge node UUID, engine, and token validated against MNSCloud API."
  rm -f "$output" "$payload"
}

bootstrap_edge_node() {
  local base token uuid hostname public_domain public_ip private_ip base_url version output payload
  base="$(api_base)"
  token="$(node_token)"
  uuid="$(node_uuid)"
  hostname="$(hostname -f 2>/dev/null || hostname)"
  public_domain="${1:-}"
  public_ip="$(runtime_public_ip "$public_domain")"
  private_ip="$(runtime_private_ip)"
  base_url=""
  if [[ -n "$public_domain" ]]; then
    base_url="https://$public_domain"
  fi
  version="$(runtime_edge_version)"
  output="$(mktemp)"
  payload="$(mktemp)"
  jq -n \
    --arg node_uuid "$uuid" \
    --arg engine "kamailio" \
    --arg hostname "$hostname" \
    --arg publicDomain "$public_domain" \
    --arg publicIP "$public_ip" \
    --arg privateIP "$private_ip" \
    --arg baseUrl "$base_url" \
    --arg version "$version" \
    '{
      node_uuid:$node_uuid,
      engine:$engine,
      hostname:$hostname,
      publicDomain:$publicDomain,
      publicIP:$publicIP,
      privateIP:$privateIP,
      baseUrl:$baseUrl,
      version:$version
    }' > "$payload"

  run curl -fsSL \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    -H "X-WebRTC-Engine: kamailio" \
    -H "Content-Type: application/json" \
    --data @"$payload" \
    "$base/api/v1/webrtc/edge/bootstrap" \
    -o "$output"
  jq type "$output" >/dev/null
  rm -f "$output" "$payload"
  ok "WebRTC edge node validated against MNSCloud API."
}

runtime_private_ip() {
  local ip_addr
  ip_addr="$(runtime_default_route_source_ip 4 || true)"
  if [[ -n "$ip_addr" ]]; then
    printf '%s\n' "$ip_addr"
    return 0
  fi
  runtime_default_route_source_ip 6 || true
}

runtime_public_ip() {
  local public_domain="$1"
  local ip_addr
  ip_addr="$(runtime_resolve_first_ip 4 "$public_domain" || true)"
  if [[ -n "$ip_addr" ]]; then
    printf '%s\n' "$ip_addr"
    return 0
  fi
  runtime_resolve_first_ip 6 "$public_domain" || true
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
