#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0
skipped=0

cd "${repo_root}"

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failed=$((failed + 1))
}

skip() {
  printf 'skip - %s: %s\n' "$1" "$2"
  skipped=$((skipped + 1))
}

run_check() {
  local name="$1"
  shift
  printf 'check - %s\n' "${name}"
  set +e
  "$@"
  local status=$?
  set -e
  if [[ "${status}" -eq 0 ]]; then
    pass "${name}"
  else
    fail "${name}"
  fi
}

need_command() {
  command -v "$1" >/dev/null 2>&1
}

shell_syntax_check() {
  bash -n scripts/*.sh \
    && bash -n custom-cont-init.d/*.sh
}

python_check() {
  python3 -m py_compile \
    gateway/pam-auth/pam-auth-helper.py \
    && find gateway modules -type d -name __pycache__ -prune -exec rm -rf {} +
}

compose_check() {
  docker compose --env-file .env.example -f compose/webtop-kde.yml config --quiet \
    && docker compose --env-file .env.example -f compose/webtop-kde.yml --profile frpc config --quiet
}

preset_compose_check() {
  local tmp_env
  tmp_env="$(mktemp)"
  local preset
  for preset in low-bandwidth balanced quality; do
    cat .env.example ".env.${preset}.example" > "${tmp_env}"
    docker compose --env-file "${tmp_env}" -f compose/webtop-kde.yml config --quiet || {
      rm -f "${tmp_env}"
      return 1
    }
  done
  rm -f "${tmp_env}"
}

baota_render_check() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local status=0

  ENV_FILE=".env.example" \
    BAOTA_COMPOSE_FILE="${tmp_dir}/docker-compose.yml" \
    BAOTA_ENV_FILE="${tmp_dir}/.env" \
    BAOTA_COMPOSE_PROFILES="frpc" \
    scripts/render-baota-compose.sh >/tmp/kde-in-webbrowser-baota-render.log \
    && docker compose --env-file "${tmp_dir}/.env" -f "${tmp_dir}/docker-compose.yml" config --quiet \
    && rg -q '^REPO_DIR=' "${tmp_dir}/.env" \
    && rg -q '\$\{HOST_HOME' "${tmp_dir}/docker-compose.yml" \
    && rg -q '^  frpc:' "${tmp_dir}/docker-compose.yml" \
    || status=$?

  rm -rf "${tmp_dir}"
  return "${status}"
}

nginx_check() {
  local tmp_certs
  tmp_certs="$(mktemp -d)"
  openssl req \
    -x509 \
    -nodes \
    -newkey rsa:2048 \
    -days 1 \
    -keyout "${tmp_certs}/kde-webtop.key" \
    -out "${tmp_certs}/kde-webtop.crt" \
    -subj "/CN=kde-webtop-gateway" >/dev/null 2>&1

  docker run --rm \
    -e GATEWAY_AUTH_PROVIDER=pam \
    -e GATEWAY_AUTH_INTERNAL_URI=/internal/pam/authz \
    -e PAM_AUTH_SOCKET_CONTAINER=/run/kde-pam-auth/pam-helper.sock \
    --add-host authelia:127.0.0.1 \
    --add-host webtop-kde:127.0.0.1 \
    -v "${repo_root}/gateway/nginx/default.conf.template:/etc/nginx/templates/default.conf.template:ro" \
    -v "${tmp_certs}:/etc/nginx/certs:ro" \
    nginx:mainline-alpine \
    sh -c 'envsubst "\${GATEWAY_AUTH_PROVIDER} \${GATEWAY_AUTH_INTERNAL_URI} \${PAM_AUTH_SOCKET_CONTAINER}" < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -t'
  local status=$?
  rm -rf "${tmp_certs}"
  return "${status}"
}

install_smoke_check() {
  if [[ -e .env || -e compose.local.yml ]]; then
    skip "install smoke" ".env or compose.local.yml already exists"
    return 0
  fi

  local tmp_mount
  tmp_mount="$(mktemp -d)"
  local status=0

  scripts/install.sh --force --preset low-bandwidth --skip-pam-helper --mount "${tmp_mount}:/mnt/validate:ro" >/tmp/kde-in-webbrowser-install-smoke.log \
    && test -s .env \
    && test -s compose.local.yml \
    && rg -q '^AUTHELIA_CONFIG_DIR=' .env \
    && docker compose --env-file .env -f compose/webtop-kde.yml -f compose.local.yml config --quiet \
    || status=$?

  rm -rf "${tmp_mount}"
  rm -f .env compose.local.yml
  return "${status}"
}

wizard_smoke_check() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local status=0

  scripts/configure-deployment.sh \
    --language en \
    --defaults \
    --force \
    --no-actions \
    --env-file "${tmp_dir}/.env" \
    --compose-file "${tmp_dir}/compose.local.yml" \
    --frpc-file "${tmp_dir}/frpc.toml" >/tmp/kde-in-webbrowser-wizard-smoke.log \
    && test -s "${tmp_dir}/.env" \
    && test ! -e "${tmp_dir}/compose.local.yml" \
    && rg -q '^FRPC_CONFIG_FILE=' "${tmp_dir}/.env" \
    && docker compose --env-file "${tmp_dir}/.env" -f compose/webtop-kde.yml config --quiet \
    || status=$?

  rm -rf "${tmp_dir}"
  return "${status}"
}

public_path_check() {
  local bad
  bad="$(
    git ls-files -co --exclude-standard \
      | rg -n '(^|/)(\.env|\.agent|\.local|_incoming|config|\.xwechat|xwechat_files|Tencent Files|WeChat Files|node_modules|backups)(/|$)|(^|/)frpc\.toml$|\.(key|pem|crt|p12|pfx)$' \
      || true
  )"
  if [[ -n "${bad}" ]]; then
    printf '%s\n' "${bad}" >&2
    return 1
  fi
}

secret_scan_check() {
  local file
  local file_matches
  local matches=""
  while IFS= read -r -d '' file; do
    [[ -f "${file}" ]] || continue
    file_matches="$(
      rg -n --pcre2 \
        'li3\.141592li|BEGIN [A-Z ]*PRIVATE KEY|^[[:space:]]*token\s*=\s*"(?!REPLACE_ME|\$\{frpc_token\})|^[[:space:]]*serverAddr\s*=\s*"(?!FRPS_PUBLIC_HOST_OR_IP|\$\{frpc_server_addr\})|45\.77\.|170\.64\.|100\.64\.0\.1|10\.10\.2\.210' \
        "${file}" \
        || true
    )"
    if [[ -n "${file_matches}" ]]; then
      matches+="${file_matches}"$'\n'
    fi
  done < <(git ls-files -co --exclude-standard -z)
  if [[ -n "${matches}" ]]; then
    printf '%s\n' "${matches}" >&2
    return 1
  fi
}

authelia_config_check() {
  local config_dir
  config_dir="${AUTHELIA_CONFIG_DIR:-}"
  if [[ -z "${config_dir}" && -f .env ]]; then
    config_dir="$(awk -F= '$1 == "AUTHELIA_CONFIG_DIR" { print $2 }' .env | tail -n 1)"
    config_dir="${config_dir%\"}"
    config_dir="${config_dir#\"}"
  fi
  if [[ -z "${config_dir}" ]]; then
    config_dir="data/authelia"
  fi
  case "${config_dir}" in
    /*) ;;
    ../*) config_dir="$(realpath -m "${repo_root}/compose/${config_dir}")" ;;
    *) config_dir="$(realpath -m "${repo_root}/${config_dir}")" ;;
  esac

  if [[ ! -f "${config_dir}/configuration.yml" ]]; then
    skip "authelia config" "no local data/authelia configuration generated"
    return 0
  fi

  docker run --rm \
    -v "${config_dir}:/config:ro" \
    "authelia/authelia:${AUTHELIA_VERSION:-4.39.20}" \
    authelia config validate --config /config/configuration.yml
}

live_stack_check() {
  if [[ "${VALIDATE_LIVE:-0}" != "1" ]]; then
    skip "live stack" "set VALIDATE_LIVE=1 to require running-container checks"
    return 0
  fi
  if [[ ! -f .env ]]; then
    printf 'VALIDATE_LIVE=1 requires .env\n' >&2
    return 1
  fi

  local gateway_port
  gateway_port="$(awk -F= '$1 == "GATEWAY_PORT" { print $2 }' .env | tail -n 1)"
  gateway_port="${gateway_port:-18080}"
  local auth_provider
  auth_provider="$(awk -F= '$1 == "GATEWAY_AUTH_PROVIDER" { print $2 }' .env | tail -n 1)"
  auth_provider="${auth_provider:-pam}"

  local compose_cmd=(docker compose --env-file .env -f compose/webtop-kde.yml)
  if [[ -f compose.local.yml ]]; then
    compose_cmd+=(-f compose.local.yml)
  fi

  "${compose_cmd[@]}" ps \
    && curl -kfsS "https://127.0.0.1:${gateway_port}/healthz" | rg -q "\"auth\":\"${auth_provider}\"" \
    && if [[ "${auth_provider}" == "pam" ]]; then
      test "$(curl -ksS -o /dev/null -w '%{http_code}' "https://127.0.0.1:${gateway_port}/auth/login")" = "200"
    else
      test "$(curl -ksS -o /dev/null -w '%{http_code}' "https://127.0.0.1:${gateway_port}/authelia/")" = "200"
    fi \
    && test "$(curl -ksS -o /dev/null -w '%{http_code}' "https://127.0.0.1:${gateway_port}/")" = "302" \
    && test "$(curl -ksS -o /dev/null -w '%{http_code}' -H 'Connection: Upgrade' -H 'Upgrade: websocket' "https://127.0.0.1:${gateway_port}/websockify")" = "302"
}

host_user_compat_live_check() {
  if [[ "${VALIDATE_LIVE:-0}" != "1" ]]; then
    skip "host-user compatibility" "set VALIDATE_LIVE=1 to require running-container checks"
    return 0
  fi
  if [[ ! -f .env ]]; then
    printf 'VALIDATE_LIVE=1 requires .env\n' >&2
    return 1
  fi

  local container_user
  container_user="$(awk -F= '$1 == "CONTAINER_USER" { print $2 }' .env | tail -n 1)"
  container_user="${container_user%\"}"
  container_user="${container_user#\"}"
  if [[ -z "${container_user}" ]]; then
    skip "host-user compatibility" "CONTAINER_USER is unset"
    return 0
  fi

  docker exec kde-webtop sh -lc '
    set -eu
    container_user="$1"
    getent passwd "${container_user}" >/dev/null
    if [ "${container_user}" != "abc" ]; then
      getent shadow "${container_user}" >/dev/null
    fi
    s6-setuidgid abc sudo -n true
    pgrep -f kwin_wayland >/dev/null
    pgrep -x plasmashell >/dev/null
  ' sh "${container_user}"
}

if ! need_command git; then
  fail "git is required"
fi
if ! need_command rg; then
  fail "ripgrep is required"
fi
if ! need_command docker; then
  fail "docker is required"
fi
if ! docker compose version >/dev/null 2>&1; then
  fail "docker compose plugin is required"
fi
if ! need_command python3; then
  fail "python3 is required"
fi
if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

run_check "shell syntax" shell_syntax_check
run_check "python syntax" python_check
run_check "compose templates" compose_check
run_check "bandwidth preset compose" preset_compose_check
run_check "baota compose render" baota_render_check
run_check "nginx gateway config" nginx_check
run_check "installer smoke" install_smoke_check
run_check "deployment wizard smoke" wizard_smoke_check
run_check "public path allowlist" public_path_check
run_check "secret scan" secret_scan_check
run_check "authelia config" authelia_config_check
run_check "live stack checks" live_stack_check
run_check "host-user compatibility" host_user_compat_live_check

printf 'summary - failed=%s skipped=%s\n' "${failed}" "${skipped}"
if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
