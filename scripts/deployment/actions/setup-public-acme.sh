#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="${repo_root}/.env"
install_certbot=true

usage() {
  cat <<'EOF'
usage: scripts/deployment/actions/setup-public-acme.sh [options]

Issue a Let's Encrypt certificate for the public gateway domain using Certbot
standalone HTTP-01 validation, install renewal hooks, and deploy the certificate
into the gateway TLS files.

Options:
  --env-file PATH          Env file to read. Default: .env
  --no-install-certbot     Do not try to install certbot if it is missing.
  -h, --help               Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      env_file="${2:?missing env file path}"
      shift 2
      ;;
    --no-install-certbot)
      install_certbot=false
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
  if [[ "${install_certbot}" != "true" ]]; then
    sudo_args+=(--no-install-certbot)
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

install_certbot_package() {
  if command -v certbot >/dev/null 2>&1; then
    return 0
  fi
  if [[ "${install_certbot}" != "true" ]]; then
    echo "certbot is required but not installed" >&2
    exit 1
  fi

  if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y certbot
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y certbot
  elif command -v yum >/dev/null 2>&1; then
    yum install -y certbot
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install certbot
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm certbot
  else
    echo "certbot is not installed and no supported package manager was found" >&2
    exit 1
  fi
}

domain="${ACME_DOMAIN:-$(read_env_key ACME_DOMAIN)}"
email="${ACME_EMAIL:-$(read_env_key ACME_EMAIL)}"
cert_name="${ACME_CERT_NAME:-$(read_env_key ACME_CERT_NAME)}"
cert_name="${cert_name:-kde-webtop-${domain}}"
http_port="${ACME_HTTP_PORT:-$(read_env_key ACME_HTTP_PORT)}"
http_port="${http_port:-80}"
staging="${ACME_STAGING:-$(read_env_key ACME_STAGING)}"
staging="${staging:-false}"
allow_no_email="${ACME_ALLOW_NO_EMAIL:-$(read_env_key ACME_ALLOW_NO_EMAIL)}"
allow_no_email="${allow_no_email:-false}"
auto_renew="${ACME_AUTO_RENEW:-$(read_env_key ACME_AUTO_RENEW)}"
auto_renew="${auto_renew:-true}"

if [[ -z "${domain}" ]]; then
  echo "ACME_DOMAIN is required" >&2
  exit 1
fi
if [[ -z "${email}" && "${allow_no_email}" != "true" ]]; then
  echo "ACME_EMAIL is required, or set ACME_ALLOW_NO_EMAIL=true" >&2
  exit 1
fi
if [[ "${http_port}" != "80" ]]; then
  echo "Let's Encrypt HTTP-01 requires public TCP port 80; ACME_HTTP_PORT=${http_port}" >&2
  exit 1
fi

install_certbot_package

if command -v ss >/dev/null 2>&1 \
  && ss -ltnH | awk '{print $4}' | grep -Eq '(^|:|\])80$'; then
  echo "TCP port 80 is already listening; certbot standalone HTTP-01 needs it free during issuance/renewal" >&2
  exit 1
fi

certbot_args=(
  certonly
  --standalone
  --preferred-challenges http
  --http-01-port "${http_port}"
  --cert-name "${cert_name}"
  -d "${domain}"
  --agree-tos
  --non-interactive
  --keep-until-expiring
)

if [[ -n "${email}" ]]; then
  certbot_args+=(--email "${email}")
else
  certbot_args+=(--register-unsafely-without-email)
fi
if [[ "${staging}" == "true" ]]; then
  certbot_args+=(--staging)
fi

certbot "${certbot_args[@]}"
"${repo_root}/scripts/deployment/actions/deploy-acme-cert.sh" --env-file "${env_file}"

safe_name="$(printf '%s' "${cert_name}" | tr -c 'A-Za-z0-9_.-' '_')"
hook_dir="/etc/letsencrypt/renewal-hooks/deploy"
install -d -m 755 "${hook_dir}"
cat >"${hook_dir}/kde-webtop-${safe_name}.sh" <<EOF
#!/bin/sh
exec "${repo_root}/scripts/deployment/actions/deploy-acme-cert.sh" --env-file "${env_file}"
EOF
chmod 755 "${hook_dir}/kde-webtop-${safe_name}.sh"

if [[ "${auto_renew}" == "true" ]] && command -v systemctl >/dev/null 2>&1; then
  certbot_bin="$(command -v certbot)"
  cat >/etc/systemd/system/kde-webtop-acme-renew.service <<EOF
[Unit]
Description=Renew ACME certificates for KDE in Web Browser
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type=oneshot
ExecStart=${certbot_bin} renew --quiet
EOF

  cat >/etc/systemd/system/kde-webtop-acme-renew.timer <<'EOF'
[Unit]
Description=Twice-daily ACME renewal for KDE in Web Browser

[Timer]
OnCalendar=*-*-* 03,15:17:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now kde-webtop-acme-renew.timer
fi

echo "ACME is configured for https://${domain}"
