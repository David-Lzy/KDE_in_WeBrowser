#!/bin/sh
set -eu

PORT="${KDE_WEBTOP_GATEWAY_PORT:-18080}"
IFACE="${KDE_WEBTOP_ALLOWED_IFACE:-tailscale0}"

apply_rules() {
  cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  "$cmd" -N DOCKER-USER 2>/dev/null || true

  while "$cmd" -D DOCKER-USER -i "$IFACE" -p tcp -m conntrack --ctorigdstport "$PORT" -j ACCEPT 2>/dev/null; do
    :
  done
  while "$cmd" -D DOCKER-USER -p tcp -m conntrack --ctorigdstport "$PORT" -j DROP 2>/dev/null; do
    :
  done

  "$cmd" -I DOCKER-USER 1 -p tcp -m conntrack --ctorigdstport "$PORT" -j DROP
  "$cmd" -I DOCKER-USER 1 -i "$IFACE" -p tcp -m conntrack --ctorigdstport "$PORT" -j ACCEPT
}

apply_rules iptables
apply_rules ip6tables
