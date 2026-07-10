#!/usr/bin/env bash
set -euo pipefail

public_ip_service="${PUBLIC_IP_SERVICE:-https://api.ipify.org}"
probe_target="${NETWORK_PROBE_TARGET:-1.1.1.1}"

is_ipv4() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+){3}$ ]]
}

is_private_ipv4() {
  local ip="$1"
  local a b c d

  is_ipv4 "${ip}" || return 1
  IFS=. read -r a b c d <<<"${ip}"

  (( a == 10 )) && return 0
  (( a == 127 )) && return 0
  (( a == 169 && b == 254 )) && return 0
  (( a == 172 && b >= 16 && b <= 31 )) && return 0
  (( a == 192 && b == 168 )) && return 0
  (( a == 100 && b >= 64 && b <= 127 )) && return 0
  (( a == 0 )) && return 0

  return 1
}

sslip_domain_for_ip() {
  local ip="$1"
  printf 'kde-%s.sslip.io\n' "${ip//./-}"
}

route_line="$(ip -4 route get "${probe_target}" 2>/dev/null | head -n 1 || true)"
local_ipv4="$(printf '%s\n' "${route_line}" | sed -nE 's/.*[[:space:]]src[[:space:]]+([0-9.]+).*/\1/p')"
route_iface="$(printf '%s\n' "${route_line}" | sed -nE 's/.*[[:space:]]dev[[:space:]]+([^[:space:]]+).*/\1/p')"
public_ipv4="$(curl -4fsS --max-time 8 "${public_ip_service}" 2>/dev/null || true)"

exposure="unknown"
reason="no_ipv4_route_or_public_ip"

if is_ipv4 "${local_ipv4:-}" && is_ipv4 "${public_ipv4:-}"; then
  if is_private_ipv4 "${local_ipv4}"; then
    exposure="private_or_nat"
    reason="local_ipv4_is_private_or_cgnat"
  elif [[ "${local_ipv4}" == "${public_ipv4}" ]]; then
    exposure="public_direct"
    reason="route_ipv4_matches_public_ipv4"
  else
    exposure="private_or_nat"
    reason="route_ipv4_differs_from_public_ipv4"
  fi
elif is_ipv4 "${local_ipv4:-}"; then
  if is_private_ipv4 "${local_ipv4}"; then
    exposure="private_or_nat"
    reason="local_ipv4_is_private_or_cgnat_public_probe_failed"
  else
    exposure="unknown"
    reason="public_probe_failed"
  fi
fi

default_domain=""
if is_ipv4 "${public_ipv4:-}"; then
  default_domain="$(sslip_domain_for_ip "${public_ipv4}")"
fi

port80_state="unknown"
port443_state="unknown"
if command -v ss >/dev/null 2>&1; then
  if ss -ltnH | awk '{print $4}' | grep -Eq '(^|:|\])80$'; then
    port80_state="listening"
  else
    port80_state="free_or_not_listening"
  fi
  if ss -ltnH | awk '{print $4}' | grep -Eq '(^|:|\])443$'; then
    port443_state="listening"
  else
    port443_state="free_or_not_listening"
  fi
fi

cat <<EOF
NETWORK_EXPOSURE=${exposure}
NETWORK_EXPOSURE_REASON=${reason}
NETWORK_ROUTE_IPV4=${local_ipv4}
NETWORK_ROUTE_IFACE=${route_iface}
NETWORK_PUBLIC_IPV4=${public_ipv4}
NETWORK_PUBLIC_IP_SERVICE=${public_ip_service}
NETWORK_DEFAULT_SSLIP_DOMAIN=${default_domain}
NETWORK_PORT_80_STATE=${port80_state}
NETWORK_PORT_443_STATE=${port443_state}
EOF
