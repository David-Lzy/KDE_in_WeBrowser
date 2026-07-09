#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

load_env_file() {
  local file="$1"
  local line key value
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    export "${key}=${value}"
  done < "${file}"
}

if [[ -f .env ]]; then
  load_env_file .env
fi

authelia_image="${AUTHELIA_IMAGE:-authelia/authelia:${AUTHELIA_VERSION:-4.39.20}}"

resolve_project_path() {
  local path="$1"
  case "${path}" in
    /*) realpath -m "${path}" ;;
    ../*) realpath -m "${repo_root}/compose/${path}" ;;
    *) realpath -m "${repo_root}/${path}" ;;
  esac
}

rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

authelia_dir="$(resolve_project_path "${AUTHELIA_CONFIG_DIR:-data/authelia}")"
assets_dir="${authelia_dir}/assets"
locales_dir="${assets_dir}/locales"
secrets_file="${authelia_dir}/secrets.env"
users_file="${authelia_dir}/users_database.yml"
config_file="${authelia_dir}/configuration.yml"

umask 077
mkdir -p "${assets_dir}" "${locales_dir}/en" "${locales_dir}/zh-CN"

if [[ -f "${secrets_file}" ]]; then
  load_env_file "${secrets_file}"
else
  AUTHELIA_JWT_SECRET="$(rand_hex)"
  AUTHELIA_SESSION_SECRET="$(rand_hex)"
  AUTHELIA_STORAGE_ENCRYPTION_KEY="$(rand_hex)"
  {
    printf 'AUTHELIA_JWT_SECRET=%s\n' "${AUTHELIA_JWT_SECRET}"
    printf 'AUTHELIA_SESSION_SECRET=%s\n' "${AUTHELIA_SESSION_SECRET}"
    printf 'AUTHELIA_STORAGE_ENCRYPTION_KEY=%s\n' "${AUTHELIA_STORAGE_ENCRYPTION_KEY}"
  } > "${secrets_file}"
fi

public_base_urls="${AUTHELIA_PUBLIC_BASE_URLS:-${GATEWAY_PUBLIC_BASE_URL:-https://127.0.0.1:18080}}"
IFS=',' read -r -a base_urls <<< "${public_base_urls}"

cookie_yaml=""
for raw_url in "${base_urls[@]}"; do
  url="$(printf '%s' "${raw_url}" | xargs)"
  [[ -z "${url}" ]] && continue
  url="${url%/}"
  host_port="${url#*://}"
  host_port="${host_port%%/*}"
  cookie_domain="${host_port%%:*}"
  cookie_yaml+="    - domain: ${cookie_domain}"$'\n'
  cookie_yaml+="      authelia_url: ${url}/authelia/"$'\n'
  cookie_yaml+="      default_redirection_url: ${url}/"$'\n'
done

if [[ -z "${cookie_yaml}" ]]; then
  echo "AUTHELIA_PUBLIC_BASE_URLS produced no usable URLs" >&2
  exit 1
fi

cat > "${config_file}" <<YAML
theme: dark

server:
  address: tcp://:9091/authelia
  asset_path: /config/assets

log:
  level: info

identity_validation:
  reset_password:
    jwt_secret: ${AUTHELIA_JWT_SECRET:?missing AUTHELIA_JWT_SECRET}

authentication_backend:
  password_reset:
    disable: true
  file:
    path: /config/users_database.yml
    watch: true

access_control:
  default_policy: one_factor

session:
  secret: ${AUTHELIA_SESSION_SECRET:?missing AUTHELIA_SESSION_SECRET}
  name: kde_webtop_authelia_session
  cookies:
${cookie_yaml}

regulation:
  max_retries: 5
  find_time: 5m
  ban_time: 15m

storage:
  encryption_key: ${AUTHELIA_STORAGE_ENCRYPTION_KEY:?missing AUTHELIA_STORAGE_ENCRYPTION_KEY}
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
YAML

cat > "${locales_dir}/en/portal.json" <<'JSON'
{
  "Login - {{authelia}}": "KDE in Web Browser - {{authelia}}",
  "Sign in": "Enter KDE Desktop",
  "Username": "KDE username",
  "Password": "Desktop password",
  "Remember me": "Keep this browser signed in",
  "Powered by {{authelia}}": "Protected by {{authelia}} for KDE in Web Browser",
  "Incorrect username or password": "KDE username or password is incorrect"
}
JSON

cat > "${locales_dir}/zh-CN/portal.json" <<'JSON'
{
  "Login - {{authelia}}": "KDE in Web Browser - {{authelia}}",
  "Sign in": "进入 KDE 桌面",
  "Username": "KDE 用户名",
  "Password": "桌面密码",
  "Remember me": "在此浏览器保持登录",
  "Powered by {{authelia}}": "由 {{authelia}} 保护的 KDE in Web Browser",
  "Incorrect username or password": "KDE 用户名或密码不正确"
}
JSON

if [[ ! -s "${assets_dir}/logo.png" || ! -s "${assets_dir}/favicon.ico" ]]; then
  tmp_svg="${assets_dir}/logo.svg"
  if docker image inspect kde-webtop:wechat-qq >/dev/null 2>&1; then
    docker run --rm --entrypoint sh \
      -v "${assets_dir}:/out" \
      kde-webtop:wechat-qq \
      -c 'cp /usr/share/icons/breeze/places/96/start-here-kde.svg /out/logo.svg' >/dev/null 2>&1 || true
  fi

  if [[ ! -s "${tmp_svg}" ]]; then
    cat > "${tmp_svg}" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect x="24" y="24" width="208" height="208" rx="48" fill="#55a99d"/>
  <path d="M72 176V80h22v39l36-39h28l-41 43 46 53h-30l-39-46v46H72z" fill="#102025"/>
  <path d="M174 82h18v18h-18zM174 119h18v55h-18z" fill="#102025"/>
</svg>
SVG
  fi

  if command -v convert >/dev/null 2>&1; then
    convert -background none -resize 256x256 "${tmp_svg}" "${assets_dir}/logo.png" >/dev/null 2>&1
    convert "${assets_dir}/logo.png" -define icon:auto-resize=64,48,32,16 "${assets_dir}/favicon.ico" >/dev/null 2>&1
  else
    echo "ImageMagick convert is required to generate Authelia logo.png" >&2
    exit 1
  fi
  rm -f "${tmp_svg}"
fi

if [[ -n "${AUTHELIA_BOOTSTRAP_PASSWORD:-}" || ! -s "${users_file}" ]]; then
  bootstrap_password="${AUTHELIA_BOOTSTRAP_PASSWORD:-${PASSWORD:-}}"
  if [[ -z "${bootstrap_password}" ]]; then
    echo "set AUTHELIA_BOOTSTRAP_PASSWORD for the initial Authelia user" >&2
    exit 1
  fi
  hash_output="$(
    docker run --rm "${authelia_image}" \
      authelia crypto hash generate argon2 \
      --password "${bootstrap_password}" \
      --no-confirm
  )"
  password_hash="$(printf '%s\n' "${hash_output}" | awk -F'Digest: ' '/^Digest: / { print $2 }')"
  if [[ -z "${password_hash}" ]]; then
    echo "failed to generate Authelia password hash" >&2
    exit 1
  fi
  authelia_user="${AUTHELIA_USER:-${HOST_USER:-davidli}}"
  authelia_display_name="${AUTHELIA_DISPLAY_NAME:-KDE Web Desktop}"
  authelia_email="${AUTHELIA_EMAIL:-${authelia_user}@localhost}"
  cat > "${users_file}" <<YAML
users:
  ${authelia_user}:
    displayname: "${authelia_display_name}"
    password: '${password_hash}'
    email: ${authelia_email}
    groups:
      - admins
YAML
fi

docker run --rm \
  -v "${authelia_dir}:/config:ro" \
  "${authelia_image}" \
  authelia config validate --config /config/configuration.yml

echo "authelia_config=${authelia_dir}"
