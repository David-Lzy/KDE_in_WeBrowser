#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${repo_root}/.env"
container_name="${CONTAINER_NAME:-kde-webtop}"
exec_env=()

read_env_key() {
  local key="$1"
  [[ -f "${env_file}" ]] || return 0
  sed -nE "s/^${key}=(.*)$/\\1/p" "${env_file}" \
    | tail -n 1 \
    | sed -E 's/^"//; s/"$//'
}

if [[ -f "${env_file}" ]]; then
  detected_container="$(
    sed -nE 's/^CONTAINER_NAME=(.*)$/\1/p' "${env_file}" \
      | tail -n 1 \
      | tr -d '"'
  )"
  if [[ -n "${detected_container}" ]]; then
    container_name="${detected_container}"
  fi

  for key in \
    HOST_USER \
    HOST_UID \
    HOST_GID \
    CONTAINER_USER \
    HOST_SSH_KEY \
    WEBTOP_LANG \
    WEBTOP_LANGUAGE \
    WEBTOP_LC_ALL \
    THEME_SYNC_LIGHT_SCHEME \
    THEME_SYNC_DARK_SCHEME \
    THEME_SYNC_LIGHT_LOOK_AND_FEEL \
    THEME_SYNC_DARK_LOOK_AND_FEEL
  do
    value="$(read_env_key "${key}")"
    if [[ -n "${value}" ]]; then
      exec_env+=("-e" "${key}=${value}")
    fi
  done
fi

if ! docker inspect "${container_name}" >/dev/null 2>&1; then
  echo "container not found: ${container_name}" >&2
  exit 1
fi

docker exec "${exec_env[@]}" "${container_name}" bash -lc '
set -euo pipefail

if [[ -x /custom-cont-init.d/40-host-user-compat.sh ]]; then
  /custom-cont-init.d/40-host-user-compat.sh
fi

if [[ ! -x /usr/local/bin/kde-webtop-session-sync ]]; then
  /custom-cont-init.d/55-kde-session-prefs.sh
fi

exec /usr/local/bin/kde-webtop-session-sync "$@"
' -- "$@"
