#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host_user="${USER:-}"
preset="balanced"
force="false"
start_stack="false"
with_frpc="false"
skip_pam_helper="false"
skip_terminal_assets="false"
mounts=()

usage() {
  cat <<'EOF'
usage: scripts/install.sh [options]

Options:
  --user USER              Host user to map into /config.
  --preset NAME            low-bandwidth, balanced, or quality. Default: balanced.
  --mount SPEC             Add a local compose bind mount, host:container[:mode].
  --with-frpc              Print the compose command with --profile frpc.
  --skip-pam-helper        Do not install the host PAM auth helper.
  --skip-terminal-assets   Do not copy host fonts and Konsole settings.
  --start                  Run docker compose up -d after generating files.
  --force                  Overwrite .env and generated compose override without prompt.
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
    --with-frpc)
      with_frpc="true"
      shift
      ;;
    --skip-pam-helper)
      skip_pam_helper="true"
      shift
      ;;
    --skip-terminal-assets)
      skip_terminal_assets="true"
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

if [[ "${#mounts[@]}" -gt 0 ]] && confirm_overwrite "compose.local.yml"; then
  write_compose_local
  echo "wrote compose.local.yml"
elif [[ "${#mounts[@]}" -eq 0 ]]; then
  echo "no extra mounts requested; compose.local.yml not modified"
fi

scripts/ensure-gateway-tls.sh

read_env_key() {
  local key="$1"
  awk -F= -v target="${key}" '$1 == target { print $2 }' .env | tail -n 1 | sed -e 's/^"//' -e 's/"$//'
}

gateway_auth_provider="$(read_env_key GATEWAY_AUTH_PROVIDER)"
gateway_auth_provider="${gateway_auth_provider:-pam}"

terminal_integration="$(read_env_key ENABLE_TERMINAL_INTEGRATION)"
terminal_integration="${terminal_integration:-true}"
sync_terminal_assets="$(read_env_key SYNC_HOST_TERMINAL_ASSETS)"
sync_terminal_assets="${sync_terminal_assets:-true}"
sync_system_font_matches="$(read_env_key SYNC_HOST_TERMINAL_SYSTEM_FONT_MATCHES)"
sync_system_font_matches="${sync_system_font_matches:-true}"

if [[ "${terminal_integration}" == "true" && "${sync_terminal_assets}" == "true" && "${skip_terminal_assets}" != "true" ]]; then
  sync_args=(--host-user "${host_user}" --env-file .env)
  sync_target_home="$(read_env_key HOST_HOME)"
  if [[ -n "${sync_target_home}" ]]; then
    sync_args+=(--target-home "${sync_target_home}")
  fi
  if [[ "${sync_system_font_matches}" != "true" ]]; then
    sync_args+=(--no-system-font-matches)
  fi
  scripts/sync-host-terminal-assets.sh "${sync_args[@]}"
elif [[ "${skip_terminal_assets}" == "true" ]]; then
  echo "skipped host terminal asset sync"
fi

if [[ "${gateway_auth_provider}" == "pam" ]]; then
  if [[ "${skip_pam_helper}" == "true" ]]; then
    echo "skipped PAM auth helper install"
  else
    scripts/install-pam-auth-helper.sh --env-file .env
  fi
fi

if [[ "${gateway_auth_provider}" == "authelia" && -n "${AUTHELIA_BOOTSTRAP_PASSWORD:-}" ]]; then
  scripts/ensure-authelia-config.sh
elif [[ "${gateway_auth_provider}" == "authelia" ]]; then
  echo "set AUTHELIA_BOOTSTRAP_PASSWORD and run scripts/ensure-authelia-config.sh before first start"
fi

compose_cmd=(docker compose --env-file .env -f compose/webtop-kde.yml)
if [[ -f compose.local.yml ]]; then
  compose_cmd+=(-f compose.local.yml)
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
