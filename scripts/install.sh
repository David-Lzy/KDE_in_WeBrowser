#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host_user="${USER:-}"
preset="balanced"
force="false"
start_stack="false"
with_wechat_qq="false"
with_frpc="false"
mounts=()

usage() {
  cat <<'EOF'
usage: scripts/install.sh [options]

Options:
  --user USER              Host user to map into /config.
  --preset NAME            low-bandwidth, balanced, or quality. Default: balanced.
  --mount SPEC             Add a local compose bind mount, host:container[:mode].
  --with-wechat-qq         Print the compose command with the WeChat/QQ override.
  --with-frpc              Print the compose command with --profile frpc.
  --start                  Run docker compose up -d after generating files.
  --force                  Overwrite .env and compose.local.yml without prompt.
  -h, --help               Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      host_user="${2:?missing user}"
      shift 2
      ;;
    --preset)
      preset="${2:?missing preset}"
      shift 2
      ;;
    --mount)
      mounts+=("${2:?missing mount spec}")
      shift 2
      ;;
    --with-wechat-qq)
      with_wechat_qq="true"
      shift
      ;;
    --with-frpc)
      with_frpc="true"
      shift
      ;;
    --start)
      start_stack="true"
      shift
      ;;
    --force)
      force="true"
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

case "${preset}" in
  low-bandwidth|balanced|quality) ;;
  *)
    echo "unknown preset: ${preset}" >&2
    exit 2
    ;;
esac

if [[ -z "${host_user}" ]]; then
  echo "could not detect host user; pass --user USER" >&2
  exit 1
fi

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

need_command docker
if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required" >&2
  exit 1
fi

cd "${repo_root}"

if [[ -e .env || -e compose.local.yml ]]; then
  scripts/backup.sh >/dev/null
fi

confirm_overwrite() {
  local path="$1"
  if [[ ! -e "${path}" || "${force}" == "true" ]]; then
    return
  fi
  if [[ ! -t 0 ]]; then
    echo "${path} exists; rerun with --force to overwrite in non-interactive mode" >&2
    exit 1
  fi
  read -r -p "${path} exists. Overwrite? [y/N] " answer
  case "${answer}" in
    y|Y|yes|YES) ;;
    *) echo "kept ${path}"; return 1 ;;
  esac
}

write_compose_local() {
  {
    echo "---"
    if [[ "${#mounts[@]}" -eq 0 ]]; then
      echo "services: {}"
      return
    fi
    echo "services:"
    echo "  webtop-kde:"
    echo "    volumes:"
    for mount in "${mounts[@]}"; do
      echo "      - \"${mount}\""
    done
  } > compose.local.yml
}

if confirm_overwrite ".env"; then
  scripts/detect-host-user.sh "${host_user}" > .env
  cat ".env.${preset}.example" >> .env
  echo "wrote .env using ${preset} preset"
fi

if confirm_overwrite "compose.local.yml"; then
  write_compose_local
  echo "wrote compose.local.yml"
fi

scripts/ensure-gateway-tls.sh
if [[ -n "${AUTHELIA_BOOTSTRAP_PASSWORD:-}" ]]; then
  scripts/ensure-authelia-config.sh
else
  echo "set AUTHELIA_BOOTSTRAP_PASSWORD and run scripts/ensure-authelia-config.sh before first start"
fi

compose_cmd=(docker compose --env-file .env -f compose/webtop-kde.yml -f compose.local.yml)
if [[ "${with_wechat_qq}" == "true" ]]; then
  compose_cmd+=(-f compose/wechat-qq.override.yml)
fi
if [[ "${with_frpc}" == "true" ]]; then
  compose_cmd+=(--profile frpc)
fi

"${compose_cmd[@]}" config --quiet

echo "compose command:"
printf ' %q' "${compose_cmd[@]}"
printf ' up -d\n'

if [[ "${start_stack}" == "true" ]]; then
  "${compose_cmd[@]}" up -d
fi

if [[ -e /dev/dri ]]; then
  echo "gpu_dri=present"
else
  echo "gpu_dri=missing"
fi
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia_smi=present"
else
  echo "nvidia_smi=missing"
fi
