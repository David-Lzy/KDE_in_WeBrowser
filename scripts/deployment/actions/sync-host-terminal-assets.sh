#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="${repo_root}/.env"
host_user="${SUDO_USER:-${USER:-}}"
target_home=""
include_system_font_matches=true

usage() {
  cat <<'EOF'
usage: scripts/deployment/actions/sync-host-terminal-assets.sh [options]

Copy the selected host user's terminal-facing assets into the project-local
desktop home mounted as /config.

Options:
  --host-user USER             Host user to copy from. Default: SUDO_USER or USER.
  --target-home PATH           Project-local desktop home. Default: HOST_HOME from .env.
  --env-file PATH              Env file to read HOST_HOME from. Default: .env.
  --no-system-font-matches     Do not copy system font files referenced by Konsole profiles.
  -h, --help                   Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-user)
      host_user="${2:?missing host user}"
      shift 2
      ;;
    --target-home)
      target_home="${2:?missing target home}"
      shift 2
      ;;
    --env-file)
      env_file="${2:?missing env file}"
      shift 2
      ;;
    --no-system-font-matches)
      include_system_font_matches=false
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

if [[ -z "${host_user}" ]]; then
  echo "host user is required" >&2
  exit 1
fi

passwd_entry="$(getent passwd "${host_user}" || true)"
if [[ -z "${passwd_entry}" ]]; then
  echo "host user not found: ${host_user}" >&2
  exit 1
fi

host_uid="$(printf '%s\n' "${passwd_entry}" | awk -F: '{print $3}')"
host_gid="$(printf '%s\n' "${passwd_entry}" | awk -F: '{print $4}')"
host_home="$(printf '%s\n' "${passwd_entry}" | awk -F: '{print $6}')"

if [[ -z "${target_home}" ]]; then
  target_home="$(read_env_key HOST_HOME)"
fi
if [[ -z "${target_home}" ]]; then
  target_home="${repo_root}/data/home/${host_user}"
else
  target_home="$(resolve_compose_path "${target_home}")"
fi

host_home="$(realpath -m "${host_home}")"
target_home="$(realpath -m "${target_home}")"

if [[ "${host_home}" == "${target_home}" ]]; then
  echo "host home and desktop home are the same; nothing to sync: ${target_home}"
  exit 0
fi

copy_count=0
system_font_count=0

copy_dir_contents() {
  local source="$1"
  local dest="$2"
  [[ -d "${source}" ]] || return 0

  install -d -m 755 "${dest}"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude='Cache/' \
      --exclude='cache/' \
      --exclude='.cache/' \
      --exclude='CACHEDIR.TAG' \
      "${source}/" "${dest}/"
  else
    cp -a "${source}/." "${dest}/"
  fi
  chown -R "${host_uid}:${host_gid}" "${dest}"
  copy_count=$((copy_count + 1))
  echo "synced directory: ${source} -> ${dest}"
}

copy_file() {
  local source="$1"
  local dest="$2"
  [[ -f "${source}" ]] || return 0

  install -d -m 755 "$(dirname "${dest}")"
  cp -a "${source}" "${dest}"
  chown "${host_uid}:${host_gid}" "${dest}"
  copy_count=$((copy_count + 1))
  echo "synced file: ${source} -> ${dest}"
}

copy_system_font_for_family() {
  local family="$1"
  local font_file dest

  [[ "${include_system_font_matches}" == "true" ]] || return 0
  command -v fc-match >/dev/null 2>&1 || return 0
  [[ -n "${family}" ]] || return 0

  font_file="$(
    fc-match -v "${family}" 2>/dev/null \
      | sed -nE 's/^[[:space:]]*file:[[:space:]]*"([^"]+)".*/\1/p' \
      | head -n 1
  )"
  [[ -n "${font_file}" && -f "${font_file}" ]] || return 0

  case "$(realpath -m "${font_file}")" in
    "${host_home}"/*|"${target_home}"/*)
      return 0
      ;;
  esac

  dest="${target_home}/.local/share/fonts/kde-webtop-system/${font_file#/}"
  install -d -m 755 "$(dirname "${dest}")"
  cp -a "${font_file}" "${dest}"
  chown "${host_uid}:${host_gid}" "${dest}"
  system_font_count=$((system_font_count + 1))
  echo "synced matched system font: ${font_file} -> ${dest}"
}

extract_konsole_font_families() {
  local profile_dir="$1"
  [[ -d "${profile_dir}" ]] || return 0
  find "${profile_dir}" -maxdepth 1 -type f -name '*.profile' -print0 \
    | xargs -0 awk -F= '
        $1 == "Font" {
          split($2, parts, ",")
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[1])
          if (parts[1] != "") {
            print parts[1]
          }
        }
      ' 2>/dev/null \
    | sort -u
}

install -d -m 755 "${target_home}" "${target_home}/.config" "${target_home}/.local/share"
chown "${host_uid}:${host_gid}" "${target_home}" "${target_home}/.config" "${target_home}/.local" "${target_home}/.local/share" 2>/dev/null || true

copy_dir_contents "${host_home}/.local/share/fonts" "${target_home}/.local/share/fonts"
copy_dir_contents "${host_home}/.fonts" "${target_home}/.fonts"
copy_dir_contents "${host_home}/.config/fontconfig" "${target_home}/.config/fontconfig"
copy_dir_contents "${host_home}/.fonts.conf.d" "${target_home}/.fonts.conf.d"
copy_file "${host_home}/.fonts.conf" "${target_home}/.fonts.conf"

copy_file "${host_home}/.config/konsolerc" "${target_home}/.config/konsolerc"
copy_dir_contents "${host_home}/.local/share/konsole" "${target_home}/.local/share/konsole"

declare -A seen_fonts=()
while IFS= read -r family; do
  [[ -n "${family}" ]] || continue
  if [[ -z "${seen_fonts[$family]+x}" ]]; then
    seen_fonts["$family"]=1
    copy_system_font_for_family "${family}"
  fi
done < <(
  extract_konsole_font_families "${host_home}/.local/share/konsole"
  extract_konsole_font_families "${target_home}/.local/share/konsole"
)

echo "terminal asset sync complete: copied=${copy_count}, matched_system_fonts=${system_font_count}, target=${target_home}"
