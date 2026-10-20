#!/usr/bin/env bash
set -Eeuo pipefail

# Issues the edge's Let's Encrypt certificates outside the sync unit sandbox: the *.<base> wildcards
# listed in the edge config (DNS-01) and the HTTP-01 certificates of the bound and primary domains.
# When any certificate was issued or renewed, re-renders Nginx and reloads it. Run by
# mnscloud-webrtc-acme.service or directly by an unconfined update.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/api.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"
. "$REPO_DIR/scripts/lib/acme.sh"

export MNSCLOUD_CERTBOT_CONTEXT=unconfined
before="$(letsencrypt_certificates_signature)"
ensure_wildcard_certificates
server_name="_"
[[ -s "$CONFIG_DIR/public.domain" ]] && server_name="$(tr -d '\r\n' < "$CONFIG_DIR/public.domain")"
# Rendering issues the HTTP-01 certificates still missing (certbot runs here, not in the sync).
render_nginx_config "$server_name"
if [[ "$(letsencrypt_certificates_signature)" != "$before" ]]; then
  validate_nginx
  run systemctl reload nginx
  ok "Edge domains now use their Let's Encrypt certificates."
fi
