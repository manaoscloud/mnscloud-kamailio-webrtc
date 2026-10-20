#!/usr/bin/env bash
set -Eeuo pipefail

# Keeps the *.<base> certificates listed in the edge config (wildcardCertificates) and, when one was
# issued or renewed, re-renders Nginx so the account domains serve it. Run by
# mnscloud-webrtc-acme.service (outside the sync unit sandbox) or directly by an unconfined update.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/api.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"
. "$REPO_DIR/scripts/lib/acme.sh"

before="$(wildcard_certificates_signature)"
ensure_wildcard_certificates
if [[ "$(wildcard_certificates_signature)" != "$before" ]]; then
  server_name="_"
  [[ -s "$CONFIG_DIR/public.domain" ]] && server_name="$(tr -d '\r\n' < "$CONFIG_DIR/public.domain")"
  render_nginx_config "$server_name"
  validate_nginx
  run systemctl reload nginx
  ok "Account WSS domains now use the wildcard certificate."
fi
