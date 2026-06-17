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

save_node_uuid() {
  local node_uuid="$1"
  [[ -n "$node_uuid" ]] || return 0
  printf '%s\n' "$node_uuid" > "$CONFIG_DIR/node.uuid"
  chmod 0600 "$CONFIG_DIR/node.uuid"
}

save_runtime_token() {
  local token="$1"
  [[ -n "$token" ]] || return 0
  printf '%s\n' "$token" > "$CONFIG_DIR/runtime.token"
  chmod 0600 "$CONFIG_DIR/runtime.token"
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
  info "RUN: curl -fsSL -H Authorization: Bearer <redacted> -H X-WebRTC-Node-UUID: $uuid $base/api/v1/realtime/webrtc/edge/config -o $output"
  curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    "$base/api/v1/realtime/webrtc/edge/config" \
    -o "$output"
  jq type "$output" >/dev/null
}

bootstrap_edge() {
  local public_domain="$1"
  local base token uuid hostname public_ip private_ip version base_url payload response_file http_code
  base="$(api_base)"
  token="$(runtime_token)"
  uuid="$(node_uuid)"
  hostname="$(hostname -f 2>/dev/null || hostname)"
  public_ip="$(runtime_public_ip "$public_domain" || true)"
  private_ip="$(runtime_private_ip || true)"
  version="$(runtime_edge_version || true)"
  base_url=""
  [[ -n "$public_domain" ]] && base_url="https://$public_domain"

  payload="$(jq -nc \
    --arg hostname "$hostname" \
    --arg publicDomain "$public_domain" \
    --arg publicIP "$public_ip" \
    --arg privateIP "$private_ip" \
    --arg baseUrl "$base_url" \
    --arg version "$version" \
    '{hostname:$hostname,publicDomain:$publicDomain,publicIP:$publicIP,privateIP:$privateIP,baseUrl:$baseUrl,version:$version}')"
  response_file="$(mktemp)"
  info "RUN: curl -fsS -X POST -H Authorization: Bearer <redacted> -H X-WebRTC-Node-UUID: $uuid $base/api/v1/realtime/webrtc/edge/bootstrap"
  http_code="$(curl -fsS -o "$response_file" -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "X-WebRTC-Node-UUID: $uuid" \
    -H "Content-Type: application/json" \
    "$base/api/v1/realtime/webrtc/edge/bootstrap" \
    --data "$payload" 2>&1)" || {
      local error_output="$http_code"
      warn "WebRTC edge bootstrap failed: ${error_output:-unknown curl error}"
      rm -f "$response_file"
      return 0
    }

  if [[ "$http_code" == "200" ]]; then
    ok "WebRTC edge runtime metadata synchronized."
  else
    warn "WebRTC edge bootstrap returned HTTP $http_code: $(tr '\n' ' ' < "$response_file" | head -c 200)"
  fi
  rm -f "$response_file"
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
