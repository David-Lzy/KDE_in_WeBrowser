#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

language=""
force=false
defaults=false
no_actions=false
start_stack=false
env_file=".env"
compose_local_file="compose.local.yml"
frpc_file="modules/frpc/frpc.toml"

declare -A env
mounts=()
frpc_enabled=false
frpc_server_addr=""
frpc_server_port="10202"
frpc_token=""
frpc_proxy_name="kde-webtop-gateway"
frpc_remote_port="18003"
frpc_web_addr="127.0.0.1"
frpc_web_port="7400"
authelia_bootstrap_password=""
generate_authelia=false
generate_tls=true
setup_host_ssh_key=false

usage() {
  cat <<'EOF'
usage: scripts/configure-deployment.sh [options]

Interactive bilingual deployment wizard. It writes a local env file and
compose override, and can optionally generate TLS, Authelia, frpc, and host SSH
key configuration.

Options:
  --language zh|en       Use Chinese or English prompts. Otherwise ask first.
  --env-file PATH        Output env file. Default: .env
  --compose-file PATH    Output local Compose override. Default: compose.local.yml
  --frpc-file PATH       Output frpc config. Default: modules/frpc/frpc.toml
  --defaults             Accept recommended defaults for all optional prompts.
  --force                Overwrite output files after backing them up.
  --no-actions           Only write files; skip TLS/Auth/SSH setup and compose start.
  --start                Ask/start the stack after writing files.
  -h, --help             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --language)
      language="${2:?missing language}"
      shift 2
      ;;
    --env-file)
      env_file="${2:?missing env file path}"
      shift 2
      ;;
    --compose-file)
      compose_local_file="${2:?missing compose file path}"
      shift 2
      ;;
    --frpc-file)
      frpc_file="${2:?missing frpc file path}"
      shift 2
      ;;
    --defaults)
      defaults=true
      shift
      ;;
    --force)
      force=true
      shift
      ;;
    --no-actions)
      no_actions=true
      shift
      ;;
    --start)
      start_stack=true
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

if [[ -n "${language}" && "${language}" != "zh" && "${language}" != "en" ]]; then
  echo "language must be zh or en" >&2
  exit 2
fi

select_language() {
  if [[ -n "${language}" ]]; then
    return
  fi
  if [[ "${defaults}" == "true" ]]; then
    language="zh"
    return
  fi
  local answer
  while true; do
    read -r -p "选择语言 / Select language [zh/en] (zh): " answer
    answer="${answer:-zh}"
    case "${answer,,}" in
      zh|cn|中文)
        language="zh"
        return
        ;;
      en|english)
        language="en"
        return
        ;;
      *)
        echo "请输入 zh 或 en / Please enter zh or en."
        ;;
    esac
  done
}

select_language

say() {
  local zh="$1"
  local en="$2"
  if [[ "${language}" == "zh" ]]; then
    printf '%s\n' "${zh}"
  else
    printf '%s\n' "${en}"
  fi
}

prompt_default() {
  local zh="$1"
  local en="$2"
  local default="$3"
  local answer
  local label
  if [[ "${language}" == "zh" ]]; then
    label="${zh}"
  else
    label="${en}"
  fi
  if [[ "${defaults}" == "true" ]]; then
    printf '%s\n' "${default}"
    return
  fi
  if [[ -n "${default}" ]]; then
    read -r -p "${label} (${default}): " answer
  else
    read -r -p "${label}: " answer
  fi
  printf '%s\n' "${answer:-${default}}"
}

prompt_bool() {
  local zh="$1"
  local en="$2"
  local default="$3"
  local answer
  local label default_label
  if [[ "${language}" == "zh" ]]; then
    label="${zh}"
  else
    label="${en}"
  fi
  case "${default}" in
    true) default_label="Y/n" ;;
    false) default_label="y/N" ;;
    *) echo "invalid bool default: ${default}" >&2; exit 2 ;;
  esac
  if [[ "${defaults}" == "true" ]]; then
    printf '%s\n' "${default}"
    return
  fi
  while true; do
    read -r -p "${label} [${default_label}]: " answer
    answer="${answer:-${default}}"
    case "${answer,,}" in
      y|yes|true|1|是|好|启用)
        printf 'true\n'
        return
        ;;
      n|no|false|0|否|不|禁用)
        printf 'false\n'
        return
        ;;
      *)
        say "请输入 yes/no，或直接回车采用推荐值。" \
            "Enter yes/no, or press Enter for the recommended value."
        ;;
    esac
  done
}

prompt_choice() {
  local zh="$1"
  local en="$2"
  local default="$3"
  local choices="$4"
  local answer
  local label
  if [[ "${language}" == "zh" ]]; then
    label="${zh}"
  else
    label="${en}"
  fi
  if [[ "${defaults}" == "true" ]]; then
    printf '%s\n' "${default}"
    return
  fi
  while true; do
    read -r -p "${label} [${choices}] (${default}): " answer
    answer="${answer:-${default}}"
    if [[ " ${choices//|/ } " == *" ${answer} "* ]]; then
      printf '%s\n' "${answer}"
      return
    fi
    say "可选值：${choices}" "Choices: ${choices}"
  done
}

prompt_required_or_skip() {
  local zh="$1"
  local en="$2"
  local answer
  local label
  if [[ "${language}" == "zh" ]]; then
    label="${zh}"
  else
    label="${en}"
  fi
  if [[ "${defaults}" == "true" ]]; then
    printf '__SKIP__\n'
    return
  fi
  while true; do
    read -r -p "${label} (type skip to skip): " answer
    if [[ "${answer,,}" == "skip" ]]; then
      printf '__SKIP__\n'
      return
    fi
    if [[ -n "${answer}" ]]; then
      printf '%s\n' "${answer}"
      return
    fi
    say "这里不能直接回车。请输入值，或者明确输入 skip 跳过。" \
        "Enter is not accepted here. Provide a value, or type skip explicitly."
  done
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    say "缺少必需命令：$1" "Missing required command: $1" >&2
    exit 1
  fi
}

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
    env["${key}"]="${value}"
  done < "${file}"
}

env_quote() {
  local value="$1"
  if [[ -z "${value}" ]]; then
    printf '\n'
  elif [[ "${value}" =~ [[:space:]#\"\\] ]]; then
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"\n' "${value}"
  else
    printf '%s\n' "${value}"
  fi
}

write_env_line() {
  local key="$1"
  local value="${env[$key]-}"
  printf '%s=' "${key}" >> "${env_file}"
  env_quote "${value}" >> "${env_file}"
}

write_env_section() {
  local title="$1"
  shift
  {
    printf '\n# %s\n' "${title}"
  } >> "${env_file}"
  local key
  for key in "$@"; do
    write_env_line "${key}"
  done
}

backup_existing() {
  local path="$1"
  [[ -e "${path}" ]] || return 0
  local stamp backup_dir
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup_dir="backups/wizard-${stamp}"
  mkdir -p "${backup_dir}"
  cp -a "${path}" "${backup_dir}/"
  say "已备份 ${path} 到 ${backup_dir}/" "Backed up ${path} to ${backup_dir}/"
}

confirm_output_path() {
  local path="$1"
  [[ -e "${path}" ]] || return 0
  if [[ "${force}" == "true" ]]; then
    backup_existing "${path}"
    return 0
  fi
  local ok
  ok="$(prompt_bool "文件 ${path} 已存在，备份并覆盖？" \
                    "File ${path} exists. Back up and overwrite it?" false)"
  if [[ "${ok}" != "true" ]]; then
    say "已取消，未覆盖 ${path}。" "Cancelled without overwriting ${path}."
    exit 1
  fi
  backup_existing "${path}"
}

url_host() {
  local url="$1"
  local host_port
  host_port="${url#*://}"
  host_port="${host_port%%/*}"
  printf '%s\n' "${host_port%%:*}"
}

is_ipv4() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+){3}$ ]]
}

build_tls_sans() {
  local urls_csv="$1"
  local sans="IP:127.0.0.1,DNS:localhost"
  local raw url host
  local -a urls
  IFS=',' read -r -a urls <<< "${urls_csv}"
  for raw in "${urls[@]}"; do
    url="$(printf '%s' "${raw}" | xargs)"
    [[ -z "${url}" ]] && continue
    host="$(url_host "${url}")"
    [[ -z "${host}" ]] && continue
    if is_ipv4 "${host}"; then
      [[ ",${sans}," == *",IP:${host},"* ]] || sans+=",IP:${host}"
    else
      [[ ",${sans}," == *",DNS:${host},"* ]] || sans+=",DNS:${host}"
    fi
  done
  printf '%s\n' "${sans}"
}

compose_path_to_repo_path() {
  local value="$1"
  case "${value}" in
    /*) printf '%s\n' "${value}" ;;
    ../*) realpath -m "${repo_root}/compose/${value}" ;;
    *) realpath -m "${repo_root}/${value}" ;;
  esac
}

repo_path_to_compose_path() {
  local value="$1"
  local absolute
  case "${value}" in
    /*)
      printf '%s\n' "${value}"
      ;;
    *)
      absolute="$(realpath -m "${repo_root}/${value}")"
      realpath -m --relative-to="${repo_root}/compose" "${absolute}"
      ;;
  esac
}

write_compose_local() {
  mkdir -p "$(dirname "${compose_local_file}")"
  {
    echo "---"
    if [[ "${#mounts[@]}" -eq 0 ]]; then
      echo "services: {}"
    else
      echo "services:"
      echo "  webtop-kde:"
      echo "    volumes:"
      local mount
      for mount in "${mounts[@]}"; do
        echo "      - \"${mount}\""
      done
    fi
  } > "${compose_local_file}"
}

write_frpc_config() {
  mkdir -p "$(dirname "${frpc_file}")"
  cat > "${frpc_file}" <<EOF
serverAddr = "${frpc_server_addr}"
serverPort = ${frpc_server_port}

[auth]
method = "token"
token = "${frpc_token}"

[webServer]
addr = "${frpc_web_addr}"
port = ${frpc_web_port}

[transport]
tcpMux = true
tcpMuxKeepaliveInterval = 60
dialServerKeepalive = 120
poolCount = 16

[[proxies]]
name = "${frpc_proxy_name}"
type = "tcp"
localIP = "gateway-nginx"
localPort = 8443
remotePort = ${frpc_remote_port}
EOF
}

write_env_file() {
  mkdir -p "$(dirname "${env_file}")"
  : > "${env_file}"
  {
    echo "# Generated by scripts/configure-deployment.sh"
  } >> "${env_file}"
  write_env_section "Compose project" \
    COMPOSE_PROJECT_NAME CONTAINER_NAME
  write_env_section "Host user and project-local desktop home" \
    HOST_USER HOST_UID HOST_GID HOST_HOME CONTAINER_USER
  write_env_section "Container session" \
    TZ WEBTOP_LANG WEBTOP_LANGUAGE WEBTOP_LC_ALL TITLE
  write_env_section "Display and GPU" \
    SHM_SIZE DRI_DEVICE DRINODE DRI_NODE NVIDIA_VISIBLE_DEVICES NVIDIA_DRIVER_CAPABILITIES PIXELFLUX_WAYLAND AUTO_GPU
  write_env_section "Selkies clipboard and scaling" \
    SELKIES_CLIPBOARD_ENABLED SELKIES_CLIPBOARD_IN_ENABLED SELKIES_CLIPBOARD_OUT_ENABLED SELKIES_ENABLE_BINARY_CLIPBOARD SELKIES_COMMAND_ENABLED SELKIES_USE_CSS_SCALING SELKIES_FORCE_ALIGNED_RESOLUTION SELKIES_SCALING_DPI ENABLE_AUTO_HIDPI_DPI
  write_env_section "Selkies video and bandwidth" \
    SELKIES_ENCODER SELKIES_FRAMERATE SELKIES_VIDEO_BITRATE SELKIES_RATE_CONTROL_MODE SELKIES_ENABLE_RATE_CONTROL SELKIES_H264_CRF SELKIES_JPEG_QUALITY SELKIES_AUDIO_BITRATE SELKIES_USE_PAINT_OVER_QUALITY SELKIES_PAINT_OVER_JPEG_QUALITY SELKIES_H264_PAINTOVER_CRF SELKIES_H264_PAINTOVER_BURST_FRAMES
  write_env_section "Wayland/Xwayland clipboard" \
    ENABLE_XWAYLAND_CLIPBOARD_BRIDGE
  write_env_section "Terminal integration" \
    ENABLE_TERMINAL_INTEGRATION HOST_SSH_HOST HOST_SSH_PORT HOST_SSH_TARGET HOST_SSH_KEY
  write_env_section "KDE theme sync" \
    ENABLE_THEME_SYNC THEME_SYNC_LIGHT_SCHEME THEME_SYNC_DARK_SCHEME THEME_SYNC_LIGHT_LOOK_AND_FEEL THEME_SYNC_DARK_LOOK_AND_FEEL
  write_env_section "WeChat/QQ module" \
    ENABLE_WECHAT_QQ_MODULE INSTALL_WECHAT INSTALL_QQ INSTALL_PCMANFM AUTO_START_WECHAT AUTO_START_QQ WECHAT_PROFILE_DIR WECHAT_FILES_DIR QQ_DATA_DIR
  write_env_section "Auth gateway" \
    GATEWAY_BIND GATEWAY_PORT GATEWAY_PUBLIC_BASE_URL GATEWAY_TLS_CERT GATEWAY_TLS_KEY GATEWAY_TLS_SANS AUTHELIA_VERSION AUTHELIA_CONFIG_DIR AUTHELIA_PUBLIC_BASE_URLS AUTHELIA_USER AUTHELIA_DISPLAY_NAME AUTHELIA_EMAIL
  write_env_section "frpc" \
    FRPC_CONFIG_FILE
}

apply_bandwidth_preset() {
  local preset="$1"
  load_env_file ".env.${preset}.example"
}

run_post_actions() {
  if [[ "${no_actions}" == "true" ]]; then
    say "已跳过 TLS、Authelia、SSH key 和启动动作（--no-actions）。" \
        "Skipped TLS, Authelia, SSH key, and start actions (--no-actions)."
    return
  fi

  if [[ "${generate_tls}" == "true" ]]; then
    local cert_path key_path
    cert_path="$(compose_path_to_repo_path "${env[GATEWAY_TLS_CERT]}")"
    key_path="$(compose_path_to_repo_path "${env[GATEWAY_TLS_KEY]}")"
    GATEWAY_TLS_CERT="${cert_path}" \
      GATEWAY_TLS_KEY="${key_path}" \
      GATEWAY_TLS_SANS="${env[GATEWAY_TLS_SANS]}" \
      scripts/ensure-gateway-tls.sh
  fi

  if [[ "${generate_authelia}" == "true" ]]; then
    if [[ "${env_file}" != ".env" ]]; then
      say "Authelia 生成仅在输出文件为 .env 时自动执行；当前已跳过。" \
          "Authelia generation only runs automatically when the output file is .env; skipped."
    else
      AUTHELIA_BOOTSTRAP_PASSWORD="${authelia_bootstrap_password}" \
        AUTHELIA_CONFIG_DIR="${env[AUTHELIA_CONFIG_DIR]}" \
        AUTHELIA_PUBLIC_BASE_URLS="${env[AUTHELIA_PUBLIC_BASE_URLS]}" \
        AUTHELIA_VERSION="${env[AUTHELIA_VERSION]}" \
        AUTHELIA_USER="${env[AUTHELIA_USER]}" \
        AUTHELIA_DISPLAY_NAME="${env[AUTHELIA_DISPLAY_NAME]}" \
        AUTHELIA_EMAIL="${env[AUTHELIA_EMAIL]}" \
        HOST_USER="${env[HOST_USER]}" \
        scripts/ensure-authelia-config.sh
    fi
  fi

  if [[ "${setup_host_ssh_key}" == "true" ]]; then
    if [[ "${env_file}" != ".env" ]]; then
      say "Host SSH key 生成仅在输出文件为 .env 时自动执行；当前已跳过。" \
          "Host SSH key setup only runs automatically when the output file is .env; skipped."
    else
      scripts/setup-host-ssh-key.sh
    fi
  fi

  local compose_cmd=(docker compose --env-file "${env_file}" -f compose/webtop-kde.yml -f "${compose_local_file}")
  if [[ "${frpc_enabled}" == "true" ]]; then
    compose_cmd+=(--profile frpc)
  fi
  "${compose_cmd[@]}" config --quiet

  if [[ "${start_stack}" == "true" ]]; then
    "${compose_cmd[@]}" up -d
  fi

  say "Compose 命令：" "Compose command:"
  printf ' %q' "${compose_cmd[@]}"
  printf ' up -d\n'
}

need_command docker
if ! docker compose version >/dev/null 2>&1; then
  say "需要 Docker Compose 插件。" "Docker Compose plugin is required." >&2
  exit 1
fi

say "KDE in Web Browser 部署向导。直接回车会采用括号里的推荐值。" \
    "KDE in Web Browser deployment wizard. Press Enter to use the recommended value in parentheses."
say "对于 token/密码等敏感必填项，必须输入值，或明确输入 skip。" \
    "For sensitive required values such as tokens/passwords, enter a value or type skip explicitly."

default_host_user="${SUDO_USER:-${USER:-}}"
host_user="$(prompt_default "宿主 Linux 用户" "Host Linux user" "${default_host_user}")"
while ! getent passwd "${host_user}" >/dev/null 2>&1; do
  say "找不到宿主用户：${host_user}" "Host user not found: ${host_user}"
  host_user="$(prompt_default "宿主 Linux 用户" "Host Linux user" "${default_host_user}")"
done

default_data_root="${repo_root}/data"
data_root="$(prompt_default "项目数据目录" "Project data directory" "${default_data_root}")"
data_root="$(realpath -m "${data_root}")"

tmp_defaults="$(mktemp)"
KDE_WEBTOP_DATA_ROOT="${data_root}" scripts/detect-host-user.sh "${host_user}" > "${tmp_defaults}"
load_env_file "${tmp_defaults}"
rm -f "${tmp_defaults}"

env[COMPOSE_PROJECT_NAME]="$(prompt_default "Compose 项目名" "Compose project name" "${env[COMPOSE_PROJECT_NAME]}")"
env[CONTAINER_NAME]="$(prompt_default "Webtop 容器名" "Webtop container name" "${env[CONTAINER_NAME]}")"
env[HOST_HOME]="$(prompt_default "容器 /config 对应的宿主目录" "Host directory mounted as /config" "${env[HOST_HOME]}")"
env[CONTAINER_USER]="$(prompt_default "容器显示用户名" "Container display username" "${env[CONTAINER_USER]}")"
env[TITLE]="$(prompt_default "浏览器窗口标题" "Browser window title" "${env[TITLE]}")"
env[TZ]="$(prompt_default "时区" "Timezone" "${env[TZ]}")"
env[WEBTOP_LANG]="$(prompt_default "KDE LANG" "KDE LANG" "${env[WEBTOP_LANG]}")"
env[WEBTOP_LANGUAGE]="$(prompt_default "KDE LANGUAGE" "KDE LANGUAGE" "${env[WEBTOP_LANGUAGE]}")"
env[WEBTOP_LC_ALL]="$(prompt_default "KDE LC_ALL" "KDE LC_ALL" "${env[WEBTOP_LC_ALL]}")"

preset="$(prompt_choice "Selkies 带宽预设" "Selkies bandwidth preset" "balanced" "low-bandwidth|balanced|quality")"
apply_bandwidth_preset "${preset}"

advanced_selkies="$(prompt_bool "是否手动调整 Selkies 视频/缩放参数？" "Manually tune Selkies video/scaling settings?" false)"
if [[ "${advanced_selkies}" == "true" ]]; then
  for key in \
    SELKIES_ENCODER SELKIES_FRAMERATE SELKIES_VIDEO_BITRATE SELKIES_RATE_CONTROL_MODE \
    SELKIES_ENABLE_RATE_CONTROL SELKIES_H264_CRF SELKIES_JPEG_QUALITY SELKIES_AUDIO_BITRATE \
    SELKIES_USE_CSS_SCALING SELKIES_FORCE_ALIGNED_RESOLUTION SELKIES_SCALING_DPI \
    SELKIES_USE_PAINT_OVER_QUALITY SELKIES_PAINT_OVER_JPEG_QUALITY \
    SELKIES_H264_PAINTOVER_CRF SELKIES_H264_PAINTOVER_BURST_FRAMES
  do
    env["${key}"]="$(prompt_default "${key}" "${key}" "${env[$key]}")"
  done
fi

env[ENABLE_XWAYLAND_CLIPBOARD_BRIDGE]="$(prompt_bool "启用 Wayland/Xwayland 文本剪贴板桥？" "Enable Wayland/Xwayland text clipboard bridge?" "${env[ENABLE_XWAYLAND_CLIPBOARD_BRIDGE]}")"
env[ENABLE_AUTO_HIDPI_DPI]="$(prompt_bool "启用浏览器 DPI 自动同步？" "Enable browser-driven DPI sync?" "${env[ENABLE_AUTO_HIDPI_DPI]}")"
env[ENABLE_THEME_SYNC]="$(prompt_bool "启用浏览器暗色/亮色同步到 KDE？" "Enable browser dark/light sync into KDE?" "${env[ENABLE_THEME_SYNC]}")"

advanced_display="$(prompt_bool "是否手动调整 GPU/显示设备参数？" "Manually tune GPU/display device settings?" false)"
if [[ "${advanced_display}" == "true" ]]; then
  for key in SHM_SIZE DRI_DEVICE DRINODE DRI_NODE NVIDIA_VISIBLE_DEVICES NVIDIA_DRIVER_CAPABILITIES PIXELFLUX_WAYLAND AUTO_GPU; do
    env["${key}"]="$(prompt_default "${key}" "${key}" "${env[$key]}")"
  done
fi

env[ENABLE_TERMINAL_INTEGRATION]="$(prompt_bool "启用 Host SSH / Docker 终端快捷方式？" "Enable Host SSH / Docker terminal shortcuts?" "${env[ENABLE_TERMINAL_INTEGRATION]}")"
if [[ "${env[ENABLE_TERMINAL_INTEGRATION]}" == "true" ]]; then
  env[HOST_SSH_HOST]="$(prompt_default "Host SSH 地址" "Host SSH address" "${env[HOST_SSH_HOST]}")"
  env[HOST_SSH_PORT]="$(prompt_default "Host SSH 端口" "Host SSH port" "${env[HOST_SSH_PORT]}")"
  env[HOST_SSH_TARGET]="$(prompt_default "Host SSH 完整目标，留空自动用 HOST_USER@HOST_SSH_HOST" "Full Host SSH target; empty uses HOST_USER@HOST_SSH_HOST" "${env[HOST_SSH_TARGET]}")"
  env[HOST_SSH_KEY]="$(prompt_default "Host SSH 私钥路径（容器内）" "Host SSH private key path inside container" "${env[HOST_SSH_KEY]}")"
  setup_host_ssh_key="$(prompt_bool "现在配置 Host SSH 免密 key？" "Configure passwordless Host SSH key now?" true)"
fi

env[ENABLE_WECHAT_QQ_MODULE]="$(prompt_bool "启用微信/QQ 模块？" "Enable WeChat/QQ module?" "${env[ENABLE_WECHAT_QQ_MODULE]}")"
if [[ "${env[ENABLE_WECHAT_QQ_MODULE]}" == "true" ]]; then
  env[INSTALL_WECHAT]="$(prompt_bool "构建镜像时安装微信？" "Install WeChat in the image?" "${env[INSTALL_WECHAT]}")"
  env[INSTALL_QQ]="$(prompt_bool "构建镜像时安装 QQ？" "Install QQ in the image?" "${env[INSTALL_QQ]}")"
  env[INSTALL_PCMANFM]="$(prompt_bool "安装 PCManFM 文件管理器？" "Install PCManFM file manager?" "${env[INSTALL_PCMANFM]}")"
  env[AUTO_START_WECHAT]="$(prompt_bool "KDE 启动后自动启动微信？" "Auto-start WeChat after KDE starts?" "${env[AUTO_START_WECHAT]}")"
  env[AUTO_START_QQ]="$(prompt_bool "KDE 启动后自动启动 QQ？" "Auto-start QQ after KDE starts?" "${env[AUTO_START_QQ]}")"
  env[WECHAT_PROFILE_DIR]="$(prompt_default "微信 profile 目录" "WeChat profile directory" "${env[WECHAT_PROFILE_DIR]}")"
  env[WECHAT_FILES_DIR]="$(prompt_default "微信聊天文件目录" "WeChat files directory" "${env[WECHAT_FILES_DIR]}")"
  env[QQ_DATA_DIR]="$(prompt_default "QQ 数据目录" "QQ data directory" "${env[QQ_DATA_DIR]}")"
fi

env[GATEWAY_BIND]="$(prompt_default "网关监听地址" "Gateway bind address" "${env[GATEWAY_BIND]}")"
env[GATEWAY_PORT]="$(prompt_default "网关 HTTPS 端口" "Gateway HTTPS port" "${env[GATEWAY_PORT]}")"
default_public_url="https://127.0.0.1:${env[GATEWAY_PORT]}"
env[GATEWAY_PUBLIC_BASE_URL]="$(prompt_default "主要访问 URL" "Primary access URL" "${default_public_url}")"

frpc_enabled="$(prompt_bool "是否生成并启用 frpc 配置？" "Generate and enable frpc config?" false)"
if [[ "${frpc_enabled}" == "true" ]]; then
  frpc_file="$(prompt_default "frpc 配置输出路径" "frpc config output path" "${frpc_file}")"
  frpc_server_addr="$(prompt_required_or_skip "frps 公网地址/IP" "frps public host/IP")"
  if [[ "${frpc_server_addr}" == "__SKIP__" ]]; then
    frpc_enabled=false
  else
    frpc_server_port="$(prompt_default "frps serverPort" "frps serverPort" "${frpc_server_port}")"
    frpc_token="$(prompt_required_or_skip "frpc token" "frpc token")"
    if [[ "${frpc_token}" == "__SKIP__" ]]; then
      frpc_enabled=false
    else
      frpc_proxy_name="$(prompt_default "frpc proxy 名称" "frpc proxy name" "${frpc_proxy_name}")"
      frpc_remote_port="$(prompt_default "frpc remotePort（远端 HTTPS 端口）" "frpc remotePort (remote HTTPS port)" "${frpc_remote_port}")"
      frpc_web_addr="$(prompt_default "frpc webServer addr" "frpc webServer addr" "${frpc_web_addr}")"
      frpc_web_port="$(prompt_default "frpc webServer port" "frpc webServer port" "${frpc_web_port}")"
    fi
  fi
fi
env[FRPC_CONFIG_FILE]="$(repo_path_to_compose_path "${frpc_file}")"

authelia_urls_default="${env[GATEWAY_PUBLIC_BASE_URL]}"
if [[ "${frpc_enabled}" == "true" ]]; then
  authelia_urls_default+=",https://${frpc_server_addr}:${frpc_remote_port}"
fi
env[AUTHELIA_PUBLIC_BASE_URLS]="$(prompt_default "Authelia 允许的公开 URL，逗号分隔" "Authelia public URLs, comma-separated" "${authelia_urls_default}")"
env[GATEWAY_TLS_SANS]="$(prompt_default "TLS subjectAltName" "TLS subjectAltName" "$(build_tls_sans "${env[AUTHELIA_PUBLIC_BASE_URLS]}")")"
env[GATEWAY_TLS_CERT]="$(prompt_default "TLS 证书路径（Compose 视角）" "TLS certificate path (Compose-relative)" "${env[GATEWAY_TLS_CERT]}")"
env[GATEWAY_TLS_KEY]="$(prompt_default "TLS 私钥路径（Compose 视角）" "TLS key path (Compose-relative)" "${env[GATEWAY_TLS_KEY]}")"

env[AUTHELIA_VERSION]="$(prompt_default "Authelia 版本" "Authelia version" "${env[AUTHELIA_VERSION]}")"
env[AUTHELIA_CONFIG_DIR]="$(prompt_default "Authelia 配置目录" "Authelia config directory" "${env[AUTHELIA_CONFIG_DIR]}")"
env[AUTHELIA_USER]="$(prompt_default "Authelia 用户名" "Authelia username" "${env[AUTHELIA_USER]}")"
env[AUTHELIA_DISPLAY_NAME]="$(prompt_default "Authelia 显示名" "Authelia display name" "${env[AUTHELIA_DISPLAY_NAME]}")"
env[AUTHELIA_EMAIL]="$(prompt_default "Authelia 邮箱" "Authelia email" "${env[AUTHELIA_EMAIL]}")"

generate_tls="$(prompt_bool "现在生成/确认本地 TLS 证书？" "Generate/ensure local TLS certificate now?" true)"
generate_authelia="$(prompt_bool "现在生成/更新 Authelia 配置？" "Generate/update Authelia config now?" true)"
if [[ "${generate_authelia}" == "true" ]]; then
  authelia_bootstrap_password="$(prompt_required_or_skip "Authelia 初始密码" "Authelia bootstrap password")"
  if [[ "${authelia_bootstrap_password}" == "__SKIP__" ]]; then
    generate_authelia=false
  fi
fi

while [[ "$(prompt_bool "是否添加额外 bind mount？" "Add an extra bind mount?" false)" == "true" ]]; do
  mount_spec="$(prompt_required_or_skip "mount 规格 host:container[:mode]" "mount spec host:container[:mode]")"
  [[ "${mount_spec}" == "__SKIP__" ]] && break
  mounts+=("${mount_spec}")
done

if [[ "${start_stack}" != "true" ]]; then
  start_stack="$(prompt_bool "写入配置后立即启动/更新 Docker Compose？" "Start/update Docker Compose after writing config?" false)"
fi

confirm_output_path "${env_file}"
confirm_output_path "${compose_local_file}"
if [[ "${frpc_enabled}" == "true" ]]; then
  confirm_output_path "${frpc_file}"
fi

write_env_file
write_compose_local
if [[ "${frpc_enabled}" == "true" ]]; then
  write_frpc_config
fi

run_post_actions

say "已写入：${env_file}" "Wrote: ${env_file}"
say "已写入：${compose_local_file}" "Wrote: ${compose_local_file}"
if [[ "${frpc_enabled}" == "true" ]]; then
  say "已写入：${frpc_file}" "Wrote: ${frpc_file}"
else
  say "未启用 frpc；如需要，重新运行 wizard 并输入 token，或手动编辑 modules/frpc/frpc.toml。" \
      "frpc is not enabled; rerun the wizard with a token, or edit modules/frpc/frpc.toml manually."
fi
