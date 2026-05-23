#!/usr/bin/env bash
set -Eeuo pipefail

nginx_tls_dir() {
  printf '%s\n' "$CONFIG_DIR/tls"
}

nginx_tls_certificate() {
  printf '%s\n' "$(nginx_tls_dir)/fullchain.pem"
}

nginx_tls_certificate_key() {
  printf '%s\n' "$(nginx_tls_dir)/privkey.pem"
}

ensure_nginx_tls_certificate() {
  local server_name="${1:-webrtc.example.com}"
  local tls_dir cert key
  tls_dir="$(nginx_tls_dir)"
  cert="$(nginx_tls_certificate)"
  key="$(nginx_tls_certificate_key)"

  install -d -m 0700 "$tls_dir"

  if [[ -s "$cert" && -s "$key" ]]; then
    return 0
  fi

  warn "No WebRTC TLS certificate found at $cert and $key."
  warn "Generating a temporary self-signed certificate. Replace it with a trusted certificate before production use."

  run openssl req -x509 -newkey rsa:2048 -nodes -days 397 \
    -keyout "$key" \
    -out "$cert" \
    -subj "/CN=$server_name" \
    -addext "subjectAltName=DNS:$server_name"

  chmod 0600 "$key"
  chmod 0644 "$cert"
}

render_nginx_config() {
  local server_name="${1:-_}"
  local cert key
  ensure_nginx_tls_certificate "$server_name"
  cert="$(nginx_tls_certificate)"
  key="$(nginx_tls_certificate_key)"

  install -d -m 0755 /etc/nginx/conf.d
  sed \
    -e "s|{{SERVER_NAME}}|$server_name|g" \
    -e "s|{{TLS_CERTIFICATE}}|$cert|g" \
    -e "s|{{TLS_CERTIFICATE_KEY}}|$key|g" \
    "$REPO_DIR/config/nginx/mnscloud-webrtc.conf.template" \
    > /etc/nginx/conf.d/mnscloud-webrtc.conf
  rm -f /etc/nginx/conf.d/default.conf
}

validate_nginx() {
  run nginx -t
}
