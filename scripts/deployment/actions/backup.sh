#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="${1:-${repo_root}/backups/${timestamp}}"

mkdir -p "${backup_dir}"

copy_if_exists() {
  local path="$1"
  if [[ -e "${repo_root}/${path}" ]]; then
    install -d -m 755 "${backup_dir}/$(dirname "${path}")"
    cp -a "${repo_root}/${path}" "${backup_dir}/${path}"
    echo "backed up ${path}"
  fi
}

copy_if_exists ".env"
copy_if_exists "compose.local.yml"
copy_if_exists "modules/frpc/frpc.toml"

echo "backup_dir=${backup_dir}"
