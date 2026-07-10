#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="${repo_root}/.env"
unit_name="kde-webtop-pam-auth.service"
pam_service_name="kde-webtop"

usage() {
  cat <<'EOF'
usage: scripts/deployment/actions/install-pam-auth-helper.sh [options]

Installs and starts the host-side PAM auth helper used by gateway-nginx.

Options:
  --env-file PATH       Env file to read. Default: .env
  --unit NAME           systemd unit name. Default: kde-webtop-pam-auth.service
  --pam-service NAME    PAM service file name. Default: kde-webtop
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      env_file="${2:?missing env file path}"
      shift 2
      ;;
    --unit)
      unit_name="${2:?missing unit name}"
      shift 2
      ;;
    --pam-service)
      pam_service_name="${2:?missing PAM service name}"
      shift 2
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

if [[ "${EUID}" -ne 0 ]]; then
  case "${env_file}" in
    /*) ;;
    *) env_file="$(realpath -m "${repo_root}/${env_file}")" ;;
  esac
  exec sudo "$0" --env-file "${env_file}" --unit "${unit_name}" --pam-service "${pam_service_name}"
fi

case "${env_file}" in
  /*) ;;
  *) env_file="$(realpath -m "${repo_root}/${env_file}")" ;;
esac

load_env_file() {
  local file="$1"
  local line key value
  [[ -f "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
      value="${value:1:${#value}-2}"
      value="${value//\\\"/\"}"
      value="${value//\\\\/\\}"
    elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    export "${key}=${value}"
  done < "${file}"
}

resolve_project_path() {
  local path="$1"
  local default="$2"
  if [[ -z "${path}" ]]; then
    path="${default}"
  fi
  case "${path}" in
    /*) realpath -m "${path}" ;;
    ../*) realpath -m "${repo_root}/compose/${path}" ;;
    *) realpath -m "${repo_root}/${path}" ;;
  esac
}

load_env_file "${env_file}"

pam_service_name="${PAM_AUTH_SERVICE:-${pam_service_name}}"
run_dir="$(resolve_project_path "${PAM_AUTH_RUN_DIR:-}" "../data/pam-auth/run")"
state_dir="$(resolve_project_path "${PAM_AUTH_STATE_DIR:-}" "../data/pam-auth/state")"

install -d -m 0755 -o root -g root "${run_dir}"
install -d -m 0700 -o root -g root "${state_dir}"

pam_file="/etc/pam.d/${pam_service_name}"
if [[ ! -f "${pam_file}" ]]; then
  if [[ -f /etc/pam.d/common-auth && -f /etc/pam.d/common-account ]]; then
    cat > "${pam_file}" <<'EOF'
auth include common-auth
account include common-account
EOF
  else
    cat > "${pam_file}" <<'EOF'
auth required pam_unix.so
account required pam_unix.so
EOF
  fi
  chmod 0644 "${pam_file}"
fi

unit_path="/etc/systemd/system/${unit_name}"
cat > "${unit_path}" <<EOF
[Unit]
Description=KDE Webtop PAM auth helper
After=network.target

[Service]
Type=simple
WorkingDirectory=${repo_root}
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 "${repo_root}/gateway/pam-auth/pam-auth-helper.py" --env-file "${env_file}"
Restart=on-failure
RestartSec=2
User=root
Group=root
UMask=0077

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${unit_name}"
systemctl restart "${unit_name}"
for _ in $(seq 1 50); do
  [[ -S "${run_dir}/pam-helper.sock" ]] && break
  sleep 0.1
done
systemctl --no-pager --full status "${unit_name}" || true

echo "pam_auth_unit=${unit_name}"
echo "pam_auth_socket=${run_dir}/pam-helper.sock"
