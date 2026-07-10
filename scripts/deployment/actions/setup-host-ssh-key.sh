#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="${repo_root}/.env"

read_env_key() {
  local key="$1"
  [[ -f "${env_file}" ]] || return 0
  sed -nE "s/^${key}=(.*)$/\\1/p" "${env_file}" \
    | tail -n 1 \
    | sed -E 's/^"//; s/"$//'
}

container_name="${CONTAINER_NAME:-$(read_env_key CONTAINER_NAME)}"
container_name="${container_name:-kde-webtop}"
host_user="${HOST_USER:-$(read_env_key HOST_USER)}"
host_user="${host_user:-${USER:-}}"
host_ssh_host="${HOST_SSH_HOST:-$(read_env_key HOST_SSH_HOST)}"
host_ssh_host="${host_ssh_host:-host.docker.internal}"
host_ssh_port="${HOST_SSH_PORT:-$(read_env_key HOST_SSH_PORT)}"
host_ssh_port="${host_ssh_port:-22}"
host_ssh_key="${HOST_SSH_KEY:-$(read_env_key HOST_SSH_KEY)}"
host_ssh_key="${host_ssh_key:-/config/.ssh/kde-webtop-host-ed25519}"

if [[ -z "${host_user}" ]]; then
  echo "HOST_USER is required" >&2
  exit 1
fi

if ! docker inspect "${container_name}" >/dev/null 2>&1; then
  echo "container not found: ${container_name}" >&2
  exit 1
fi

for _ in $(seq 1 60); do
  if [[ "$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" == "true" ]]; then
    break
  fi
  sleep 1
done

if [[ "$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" != "true" ]]; then
  echo "container is not running: ${container_name}" >&2
  exit 1
fi

passwd_entry="$(getent passwd "${host_user}" || true)"
if [[ -z "${passwd_entry}" ]]; then
  echo "host user not found: ${host_user}" >&2
  exit 1
fi

host_home="$(printf '%s\n' "${passwd_entry}" | awk -F: '{print $6}')"
host_ssh_dir="${host_home}/.ssh"
authorized_keys="${host_ssh_dir}/authorized_keys"

install -d -m 700 "${host_ssh_dir}"
touch "${authorized_keys}"
chmod 600 "${authorized_keys}"

pub_key="$(
  docker exec \
    --user abc \
    -e HOST_SSH_KEY="${host_ssh_key}" \
    "${container_name}" \
    bash -lc '
set -euo pipefail

install -d -m 700 /config/.ssh
if [[ ! -f "${HOST_SSH_KEY}" ]]; then
  ssh-keygen -t ed25519 -N "" -C "kde-webtop-host" -f "${HOST_SSH_KEY}" >/dev/null
fi
if [[ ! -f "${HOST_SSH_KEY}.pub" ]]; then
  ssh-keygen -y -f "${HOST_SSH_KEY}" >"${HOST_SSH_KEY}.pub"
fi
chmod 600 "${HOST_SSH_KEY}"
chmod 644 "${HOST_SSH_KEY}.pub"
cat "${HOST_SSH_KEY}.pub"
'
)"

if ! grep -Fq "${pub_key}" "${authorized_keys}"; then
  printf 'no-agent-forwarding,no-X11-forwarding,no-port-forwarding %s\n' "${pub_key}" >>"${authorized_keys}"
fi
chmod 600 "${authorized_keys}"

docker exec \
  --user abc \
  -e HOST_SSH_HOST="${host_ssh_host}" \
  -e HOST_SSH_PORT="${host_ssh_port}" \
  "${container_name}" \
  bash -lc '
set -euo pipefail

install -d -m 700 /config/.ssh
touch /config/.ssh/known_hosts
ssh-keygen -R "[${HOST_SSH_HOST}]:${HOST_SSH_PORT}" -f /config/.ssh/known_hosts >/dev/null 2>&1 || true
ssh-keyscan -p "${HOST_SSH_PORT}" "${HOST_SSH_HOST}" >>/config/.ssh/known_hosts 2>/dev/null || true
chmod 600 /config/.ssh/known_hosts
'

docker exec \
  --user abc \
  -e HOST_SSH_KEY="${host_ssh_key}" \
  "${container_name}" \
  ssh \
    -i "${host_ssh_key}" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o PreferredAuthentications=publickey \
    -o PasswordAuthentication=no \
    -o StrictHostKeyChecking=accept-new \
    -p "${host_ssh_port}" \
    "${host_user}@${host_ssh_host}" \
    'printf "host ssh key ok\n"'

echo "installed host SSH key for ${host_user}@${host_ssh_host}:${host_ssh_port}"
