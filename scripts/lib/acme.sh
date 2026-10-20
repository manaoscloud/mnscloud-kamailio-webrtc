#!/usr/bin/env bash
set -Eeuo pipefail

# Wildcard certificates (*.<base>) for the WebRTC domains generated per PABX/Softswitch account.
# Let's Encrypt DNS-01: the auth/cleanup hook asks the MNSCloud API to publish only the public
# challenge TXT value; this edge never holds DNS provider credentials and its private key never
# leaves it. The API decides which bases this edge may hold (config .data.wildcardCertificates).

ACME_RETRY_SECONDS="${MNSCLOUD_ACME_RETRY_SECONDS:-3600}"
ACME_RENEW_SECONDS="${MNSCLOUD_ACME_RENEW_SECONDS:-2592000}"

wildcard_bases() {
  [[ -s "$CONFIG_DIR/config.json" ]] || return 0
  jq -r '.data.wildcardCertificates[]? | .base // empty' "$CONFIG_DIR/config.json" 2>/dev/null |
    grep -E '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' || true
}

wildcard_cert_name() {
  printf 'wildcard.%s\n' "$1"
}

wildcard_live_dir() {
  printf '/etc/letsencrypt/live/%s\n' "$(wildcard_cert_name "$1")"
}

# Base of a generated account domain served by a held wildcard (one label below the base).
wildcard_base_for_domain() {
  local domain="$1" base
  while IFS= read -r base; do
    [[ -n "$base" ]] || continue
    if [[ "$domain" == *".$base" && "${domain%."$base"}" != *.* ]]; then
      printf '%s\n' "$base"
      return 0
    fi
  done < <(wildcard_bases)
  return 1
}

wildcard_certbot_email() {
  local email
  email="$(nginx_config_value '.data.wildcardCertbotEmail' '')"
  [[ -n "$email" ]] || email="$(nginx_certbot_email)"
  printf '%s\n' "$email"
}

acme_api_call() {
  local method="$1" path="$2" body="${3:-}" output="$4"
  local args=(-fsS -o "$output" -w '%{http_code}' -X "$method"
    -H "Authorization: Bearer $(runtime_token)"
    -H "X-WebRTC-Node-UUID: $(node_uuid)")
  [[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' --data "$body")
  curl "${args[@]}" "$(api_base)/api/v1/realtime/webrtc/edge/$path"
}

report_wildcard_certificate() {
  local base="$1" status="$2" expires="${3:-}" error="${4:-}" body output code
  body="$(jq -nc --arg base "$base" --arg status "$status" --arg expiresAt "$expires" --arg error "$error" \
    '{base:$base,status:$status,expiresAt:(if $expiresAt == "" then null else $expiresAt end),error:(if $error == "" then null else $error end)}')"
  output="$(mktemp)"
  code="$(acme_api_call POST wildcard-certificates "$body" "$output" 2>/dev/null || true)"
  [[ "$code" == "200" ]] || warn "Wildcard certificate report for $base returned HTTP ${code:-none}."
  rm -f "$output"
}

wildcard_certificate_expiry() {
  local cert
  cert="$(wildcard_live_dir "$1")/fullchain.pem"
  [[ -s "$cert" ]] || return 1
  date -u -d "$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)" '+%Y-%m-%dT%H:%M:%SZ'
}

ensure_wildcard_certificate() {
  local base="$1" live email expires failed_marker last_failure now
  live="$(wildcard_live_dir "$base")"
  failed_marker="$STATE_DIR/acme/wildcard.$base.failed"
  install -d -m 0700 "$STATE_DIR/acme"
  if [[ -s "$live/fullchain.pem" && -s "$live/privkey.pem" ]] &&
    openssl x509 -in "$live/fullchain.pem" -noout -checkend "$ACME_RENEW_SECONDS" >/dev/null 2>&1; then
    report_wildcard_certificate "$base" issued "$(wildcard_certificate_expiry "$base")"
    return 0
  fi
  # A failed attempt waits before retrying: Let's Encrypt rate limits are shared by every edge.
  now="$(date +%s)"
  last_failure="$(cat "$failed_marker" 2>/dev/null || printf '0')"
  if ((now - last_failure < ACME_RETRY_SECONDS)); then
    warn "Wildcard certificate for *.$base failed recently; next attempt after $((ACME_RETRY_SECONDS - now + last_failure)) s."
    return 0
  fi
  # The sync unit sees /etc read-only: the Let's Encrypt directories must exist before (an
  # MNSCloud Agent update creates them). No failure marker: nothing was asked to Let's Encrypt.
  if [[ ! -d /etc/letsencrypt || ! -w /etc/letsencrypt ]]; then
    report_wildcard_certificate "$base" failed '' 'Let'"'"'s Encrypt directories are missing or read-only on the WebRTC edge; run the MNSCloud Agent update'
    warn "Let's Encrypt directories are not writable here; the next MNSCloud Agent update prepares them."
    return 0
  fi
  if ! command -v certbot >/dev/null 2>&1; then
    report_wildcard_certificate "$base" failed '' 'certbot is not installed on the WebRTC edge'
    return 0
  fi
  email="$(wildcard_certbot_email)"
  report_wildcard_certificate "$base" pending
  info "Requesting wildcard certificate *.$base with DNS-01 through the MNSCloud API."
  if certbot certonly --manual --preferred-challenges dns \
    --manual-auth-hook "$INSTALL_DIR/scripts/acme-dns-hook.sh auth" \
    --manual-cleanup-hook "$INSTALL_DIR/scripts/acme-dns-hook.sh cleanup" \
    --cert-name "$(wildcard_cert_name "$base")" \
    -d "*.$base" \
    --non-interactive --agree-tos --email "$email" \
    --deploy-hook 'systemctl reload nginx' \
    --keep-until-expiring; then
    rm -f "$failed_marker"
    expires="$(wildcard_certificate_expiry "$base" || true)"
    report_wildcard_certificate "$base" issued "$expires"
    ok "Wildcard certificate *.$base issued (expires $expires)."
    return 0
  fi
  printf '%s\n' "$now" > "$failed_marker"
  report_wildcard_certificate "$base" failed '' "Let's Encrypt DNS-01 issuance failed for *.$base; see /var/log/letsencrypt on the edge."
  warn "Wildcard certificate *.$base could not be issued; account domains keep a temporary self-signed certificate."
}

# Unconfined runs (install, MNSCloud Agent update) prepare the Let's Encrypt state for the sync unit.
prepare_letsencrypt_dirs() {
  install -d -m 0755 /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt 2>/dev/null ||
    warn "Could not prepare the Let's Encrypt directories (read-only context)."
}

# A new edge version may fix what made the last attempt fail: retry at once.
clear_wildcard_failures() {
  rm -f "$STATE_DIR"/acme/wildcard.*.failed 2>/dev/null || true
}

# Fingerprints of the held wildcard certificates (detects an issuance or renewal).
wildcard_certificates_signature() {
  local base cert
  while IFS= read -r base; do
    [[ -n "$base" ]] || continue
    cert="$(wildcard_live_dir "$base")/fullchain.pem"
    [[ -s "$cert" ]] && openssl x509 -in "$cert" -noout -fingerprint -sha256 2>/dev/null
  done < <(wildcard_bases)
  return 0
}

# Called by the sync: issuance runs in mnscloud-webrtc-acme.service, outside the sync sandbox
# (snap Certbot cannot run under NoNewPrivileges/ProtectHome). Without that unit, run it here.
request_wildcard_certificates() {
  [[ -n "$(wildcard_bases)" ]] || return 0
  if [[ -f /etc/systemd/system/mnscloud-webrtc-acme.service ]]; then
    systemctl start --no-block mnscloud-webrtc-acme.service ||
      warn "Could not start mnscloud-webrtc-acme.service."
    return 0
  fi
  ensure_wildcard_certificates
}

ensure_wildcard_certificates() {
  local base
  while IFS= read -r base; do
    [[ -n "$base" ]] || continue
    ensure_wildcard_certificate "$base" || warn "Wildcard certificate step failed for *.$base."
  done < <(wildcard_bases)
}

# Name servers of the zone that contains the challenge name (walks up to the delegated zone).
acme_zone_nameservers() {
  local name="$1" zone ns
  zone="${name#*.}"
  while [[ "$zone" == *.* ]]; do
    ns="$(dig +short NS "$zone" 2>/dev/null | sed 's/\.$//' | grep -v '^;' || true)"
    if [[ -n "$ns" ]]; then
      printf '%s\n' "$ns"
      return 0
    fi
    zone="${zone#*.}"
  done
  return 1
}
