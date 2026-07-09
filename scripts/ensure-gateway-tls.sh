#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

cert="${GATEWAY_TLS_CERT:-ssl/kde-webtop.crt}"
key="${GATEWAY_TLS_KEY:-ssl/kde-webtop.key}"
days="${GATEWAY_TLS_DAYS:-825}"
common_name="${GATEWAY_TLS_COMMON_NAME:-kde-webtop-gateway}"
sans="${GATEWAY_TLS_SANS:-IP:127.0.0.1,DNS:localhost}"

if [[ -s "$cert" && -s "$key" ]]; then
  exit 0
fi

install -d -m 700 "$(dirname "$cert")" "$(dirname "$key")"

openssl req \
  -x509 \
  -nodes \
  -newkey rsa:2048 \
  -days "$days" \
  -keyout "$key" \
  -out "$cert" \
  -subj "/CN=${common_name}" \
  -addext "subjectAltName=${sans}"

chmod 600 "$key"
chmod 644 "$cert"
