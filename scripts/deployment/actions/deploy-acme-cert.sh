#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="${repo_root}/.env"
reload_gateway=true

usage() {
  cat <<'EOF'
usage: scripts/deployment/actions/deploy-acme-cert.sh [options]

Copy the current Let's Encrypt certificate into the gateway TLS files and
reload gateway-nginx when it is running.

Options:
  --env-file PATH       Env file to read. Default: .env
  --no-reload           Copy files without reloading gateway-nginx.
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      env_file="${2:?missing env file path}"
      shift 2
      ;;
    --no-reload)
      reload_gateway=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

env_file="$(realpath -m "${env_file}")"

if [[ "${EUID}" -ne 0 ]]; then
  sudo_args=(--env-file "${env_file}")
  if [[ "${reload_gateway}" != "true" ]]; then
    sudo_args+=(--no-reload)
  fi
  exec sudo "$0" "${sudo_args[@]}"
fi

read_env_key() {
  local key="$1"
  [[ -f "${env_file}" ]] || return 0
  awk -F= -v target="${key}" '
    $1 == target {
      value = substr($0, index($0, "=") + 1)
      gsub(/^"|"$/, "", value)
      print value
    }
  ' "${env_file}" | tail -n 1
}

resolve_compose_path() {
  local value="$1"
  if [[ "${value}" = /* ]]; then
    realpath -m "${value}"
  else
    realpath -m "${repo_root}/compose/${value}"
  fi
}

domain="${ACME_DOMAIN:-$(read_env_key ACME_DOMAIN)}"
cert_name="${ACME_CERT_NAME:-$(read_env_key ACME_CERT_NAME)}"
cert_name="${cert_name:-kde-webtop-${domain}}"

gateway_cert="${GATEWAY_TLS_CERT:-$(read_env_key GATEWAY_TLS_CERT)}"
gateway_key="${GATEWAY_TLS_KEY:-$(read_env_key GATEWAY_TLS_KEY)}"
gateway_cert="${gateway_cert:-../ssl/kde-webtop-acme.fullchain.pem}"
gateway_key="${gateway_key:-../ssl/kde-webtop-acme.privkey.pem}"

if [[ -z "${domain}" ]]; then
  echo "ACME_DOMAIN is required" >&2
  exit 1
fi

live_dir="/etc/letsencrypt/live/${cert_name}"
fullchain="${live_dir}/fullchain.pem"
privkey="${live_dir}/privkey.pem"

if [[ ! -s "${fullchain}" || ! -s "${privkey}" ]]; then
  echo "certificate files not found for cert name ${cert_name}: ${live_dir}" >&2
  exit 1
fi

cert_dest="$(resolve_compose_path "${gateway_cert}")"
key_dest="$(resolve_compose_path "${gateway_key}")"

install -d -m 755 "$(dirname "${cert_dest}")"
install -d -m 700 "$(dirname "${key_dest}")"
install -m 644 "${fullchain}" "${cert_dest}"
install -m 600 "${privkey}" "${key_dest}"

if [[ "${reload_gateway}" == "true" ]] && command -v docker >/dev/null 2>&1; then
  project_name="$(read_env_key COMPOSE_PROJECT_NAME)"
  project_name="${project_name:-kde-in-web-browser}"
  gateway_container="$(
    docker ps -q \
      --filter "label=com.docker.compose.project=${project_name}" \
      --filter "label=com.docker.compose.service=gateway-nginx" \
      | head -n 1
  )"
  if [[ -n "${gateway_container}" ]]; then
    docker exec "${gateway_container}" nginx -s reload >/dev/null 2>&1 \
      || docker kill -s HUP "${gateway_container}" >/dev/null 2>&1 \
      || true
  fi
fi

echo "deployed ACME certificate for ${domain} to ${cert_dest} and ${key_dest}"
