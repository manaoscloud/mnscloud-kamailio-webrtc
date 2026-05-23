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

nginx_acme_webroot() {
  printf '%s\n' '/var/www/mnscloud-webrtc-acme'
}

nginx_domain_tls_dir() {
  local domain="$1"
  printf '%s\n' "$(nginx_tls_dir)/domains/$domain"
}

nginx_config_value() {
  local jq_filter="$1"
  local fallback="${2:-}"
  if [[ -s "$CONFIG_DIR/config.json" ]]; then
    jq -r "$jq_filter // empty" "$CONFIG_DIR/config.json" 2>/dev/null | head -n 1
    return 0
  fi
  printf '%s\n' "$fallback"
}

nginx_certbot_email() {
  nginx_config_value '.data.parameters[]? | select(.key == "certbot_email") | .value' ''
}

nginx_domain_list_json() {
  if [[ -s "$CONFIG_DIR/config.json" ]]; then
    jq -c '[.data.domains[]? | select(.domain and .autoProvision != 0)]' "$CONFIG_DIR/config.json"
    return 0
  fi
  printf '[]\n'
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

ensure_nginx_domain_certificate() {
  local domain="$1"
  local provider="${2:-letsencrypt}"
  local cert key tls_dir le_cert le_key email

  tls_dir="$(nginx_domain_tls_dir "$domain")"
  cert="$tls_dir/fullchain.pem"
  key="$tls_dir/privkey.pem"
  le_cert="/etc/letsencrypt/live/$domain/fullchain.pem"
  le_key="/etc/letsencrypt/live/$domain/privkey.pem"
  install -d -m 0700 "$tls_dir"

  if [[ "$provider" == "letsencrypt" && -s "$le_cert" && -s "$le_key" ]]; then
    ln -sf "$le_cert" "$cert"
    ln -sf "$le_key" "$key"
    return 0
  fi

  if [[ "$provider" == "letsencrypt" && ! -s "$cert" ]] && command -v certbot >/dev/null 2>&1; then
    email="$(nginx_certbot_email)"
    if [[ -n "$email" ]]; then
      install -d -m 0755 "$(nginx_acme_webroot)"
      if certbot certonly --webroot \
        -w "$(nginx_acme_webroot)" \
        -d "$domain" \
        --non-interactive \
        --agree-tos \
        --email "$email" \
        --keep-until-expiring; then
        ln -sf "$le_cert" "$cert"
        ln -sf "$le_key" "$key"
        return 0
      fi
      warn "Let's Encrypt issuance failed for $domain. Falling back to a temporary self-signed certificate."
    else
      warn "Parameter certbot_email is missing. Falling back to a temporary self-signed certificate for $domain."
    fi
  fi

  if [[ -s "$cert" && -s "$key" ]]; then
    return 0
  fi

  if [[ "$provider" == "manual" ]]; then
    warn "Manual certificate for $domain was not found at $cert and $key. Generating temporary self-signed certificate."
  fi

  run openssl req -x509 -newkey rsa:2048 -nodes -days 397 \
    -keyout "$key" \
    -out "$cert" \
    -subj "/CN=$domain" \
    -addext "subjectAltName=DNS:$domain"
  chmod 0600 "$key"
  chmod 0644 "$cert"
}

render_nginx_http_server() {
  local server_names="$1"
  cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $server_names;

    location = /health {
        access_log off;
        return 200 "ok\\n";
    }

    location ^~ /.well-known/acme-challenge/ {
        root $(nginx_acme_webroot);
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 308 https://\$host\$request_uri;
    }
}

EOF
}

render_nginx_https_server() {
  local server_name="$1"
  local cert="$2"
  local key="$3"
  cat <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name $server_name;

    ssl_certificate $cert;
    ssl_certificate_key $key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:MNSCloudWebRTCSSL:10m;
    ssl_session_timeout 1d;
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=31536000" always;

    location = /health {
        access_log off;
        return 200 "ok\\n";
    }

    location /ws {
        proxy_pass http://127.0.0.1:5066;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}

EOF
}

render_nginx_config() {
  local server_name="${1:-_}"
  local cert key config_tmp domains_json domain_count i domain provider server_names domain_cert domain_key
  ensure_nginx_tls_certificate "$server_name"
  cert="$(nginx_tls_certificate)"
  key="$(nginx_tls_certificate_key)"
  install -d -m 0755 /etc/nginx/conf.d "$(nginx_acme_webroot)"

  domains_json="$(nginx_domain_list_json)"
  domain_count="$(jq 'length' <<< "$domains_json")"
  server_names="$server_name"
  for ((i = 0; i < domain_count; i++)); do
    domain="$(jq -r ".[$i].domain" <<< "$domains_json")"
    [[ -n "$domain" && "$domain" != "null" ]] || continue
    [[ "$domain" != "$server_name" ]] || continue
    server_names="$server_names $domain"
  done

  config_tmp="$(mktemp)"
  render_nginx_http_server "$server_names" > "$config_tmp"
  render_nginx_https_server "$server_name" "$cert" "$key" >> "$config_tmp"

  for ((i = 0; i < domain_count; i++)); do
    domain="$(jq -r ".[$i].domain" <<< "$domains_json")"
    provider="$(jq -r ".[$i].certificateProvider // \"letsencrypt\"" <<< "$domains_json")"
    [[ -n "$domain" && "$domain" != "null" ]] || continue
    [[ "$domain" != "$server_name" ]] || continue
    ensure_nginx_domain_certificate "$domain" "$provider"
    domain_cert="$(nginx_domain_tls_dir "$domain")/fullchain.pem"
    domain_key="$(nginx_domain_tls_dir "$domain")/privkey.pem"
    render_nginx_https_server "$domain" "$domain_cert" "$domain_key" >> "$config_tmp"
  done

  install -m 0644 "$config_tmp" /etc/nginx/conf.d/mnscloud-webrtc.conf
  rm -f "$config_tmp"
  rm -f /etc/nginx/conf.d/default.conf
}

validate_nginx() {
  run nginx -t
}
