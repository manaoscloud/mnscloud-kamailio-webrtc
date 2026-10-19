#!/usr/bin/env bash
set -Eeuo pipefail

# Certbot DNS-01 manual hook (auth | cleanup) for the WebRTC edge wildcard certificate.
# Certbot provides CERTBOT_DOMAIN (base, without "*.") and CERTBOT_VALIDATION (public TXT value).
# The MNSCloud API publishes the value; this script only waits for it on the zone name servers.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/api.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"
. "$REPO_DIR/scripts/lib/acme.sh"

MODE="${1:-}"
DOMAIN="${CERTBOT_DOMAIN:-}"
VALUE="${CERTBOT_VALIDATION:-}"
NAME="_acme-challenge.${DOMAIN}"
API_WAIT_SECONDS="${MNSCLOUD_ACME_API_WAIT_SECONDS:-300}"
DNS_WAIT_SECONDS="${MNSCLOUD_ACME_DNS_WAIT_SECONDS:-300}"

[[ -n "$DOMAIN" && "$VALUE" =~ ^[A-Za-z0-9_-]{20,128}$ ]] || die "CERTBOT_DOMAIN and CERTBOT_VALIDATION are required."
install -d -m 0700 "$STATE_DIR/acme"
STATE_FILE="$STATE_DIR/acme/challenge.$VALUE"

auth() {
  local output code uuid state waited=0 ns found
  output="$(mktemp)"
  code="$(acme_api_call POST acme-challenges "$(jq -nc --arg name "$NAME" --arg value "$VALUE" '{name:$name,value:$value}')" "$output" || true)"
  [[ "$code" == "200" ]] || { warn "ACME challenge rejected (HTTP ${code:-none}): $(head -c 300 "$output")"; rm -f "$output"; exit 1; }
  uuid="$(jq -r '.data.item.challengeUUID // empty' "$output")"
  rm -f "$output"
  [[ -n "$uuid" ]] || die "ACME challenge response has no challengeUUID."
  printf '%s\n' "$uuid" > "$STATE_FILE"
  while :; do
    output="$(mktemp)"
    acme_api_call GET "acme-challenges/$uuid" '' "$output" >/dev/null 2>&1 || true
    state="$(jq -r '.data.item.state // empty' "$output" 2>/dev/null || true)"
    rm -f "$output"
    [[ "$state" == "published" ]] && break
    [[ "$state" == "failed" ]] && die "MNSCloud could not publish $NAME."
    ((waited >= API_WAIT_SECONDS)) && die "Timed out waiting for MNSCloud to publish $NAME (state ${state:-unknown})."
    sleep 5
    waited=$((waited + 5))
  done
  # Let's Encrypt queries the authoritative servers: wait until every one answers the value.
  waited=0
  while :; do
    found=1
    while IFS= read -r ns; do
      [[ -n "$ns" ]] || continue
      dig +short TXT "$NAME" "@$ns" 2>/dev/null | tr -d '"' | grep -qx -- "$VALUE" || found=0
    done < <(acme_zone_nameservers "$NAME" || true)
    ((found == 1)) && break
    ((waited >= DNS_WAIT_SECONDS)) && die "Timed out waiting for $NAME on the zone name servers."
    sleep 10
    waited=$((waited + 10))
  done
  ok "DNS-01 value for $NAME is published."
}

cleanup() {
  local uuid output
  uuid="$(cat "$STATE_FILE" 2>/dev/null || true)"
  rm -f "$STATE_FILE"
  [[ -n "$uuid" ]] || return 0
  output="$(mktemp)"
  acme_api_call DELETE "acme-challenges/$uuid" '' "$output" >/dev/null 2>&1 || warn "ACME challenge release failed; it expires on its own within one hour."
  rm -f "$output"
}

case "$MODE" in
  auth) auth ;;
  cleanup) cleanup ;;
  *) die "Usage: acme-dns-hook.sh auth|cleanup" ;;
esac
