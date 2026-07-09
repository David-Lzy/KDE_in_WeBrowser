#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_TERMINAL_INTEGRATION:-true}" != "true" ]]; then
  echo "[terminal-integration] Disabled"
  exit 0
fi

host_user="${HOST_USER:-}"
container_user="${CONTAINER_USER:-${host_user:+docker_${host_user}}}"
host_ssh_host="${HOST_SSH_HOST:-host.docker.internal}"
host_ssh_port="${HOST_SSH_PORT:-22}"
host_ssh_target="${HOST_SSH_TARGET:-}"

if [[ -z "${host_ssh_target}" && -n "${host_user}" ]]; then
  host_ssh_target="${host_user}@${host_ssh_host}"
fi

if [[ -z "${host_ssh_target}" ]]; then
  echo "[terminal-integration] HOST_SSH_TARGET is unset and HOST_USER is empty" >&2
  exit 1
fi

install -d -m 755 /usr/local/bin /config/Desktop /config/.config \
  /config/.cache /config/.fonts /config/.local/share/applications \
  /config/.local/share/fonts /config/.local/share/konsole

chown -R abc:abc /config/.cache /config/.fonts /config/.local/share/fonts 2>/dev/null || true
if command -v fc-cache >/dev/null 2>&1; then
  s6-setuidgid abc env HOME=/config XDG_CACHE_HOME=/config/.cache \
    XDG_DATA_HOME=/config/.local/share \
    fc-cache -f /config/.local/share/fonts /config/.fonts >/dev/null 2>&1 || true
fi

read_ini_value() {
  local file="$1"
  local group="$2"
  local key="$3"

  [[ -f "${file}" ]] || return 0
  awk -F= -v target_group="${group}" -v target_key="${key}" '
    /^\[/ {
      current = $0
      gsub(/^\[|\]$/, "", current)
      next
    }
    current == target_group && $1 == target_key {
      value = substr($0, index($0, "=") + 1)
      print value
      exit
    }
  ' "${file}"
}

profile_candidates=()

add_profile_candidate() {
  local file="$1"
  local existing
  [[ -f "${file}" ]] || return 0
  for existing in "${profile_candidates[@]}"; do
    [[ "${existing}" == "${file}" ]] && return 0
  done
  profile_candidates+=("${file}")
}

default_profile="$(read_ini_value /config/.config/konsolerc "Desktop Entry" "DefaultProfile" || true)"
if [[ -n "${default_profile}" ]]; then
  add_profile_candidate "/config/.local/share/konsole/${default_profile}"
fi

while IFS= read -r profile_file; do
  if grep -q '^Font=' "${profile_file}" 2>/dev/null; then
    add_profile_candidate "${profile_file}"
  fi
done < <(find /config/.local/share/konsole -maxdepth 1 -type f -name '*.profile' 2>/dev/null | sort)

while IFS= read -r profile_file; do
  add_profile_candidate "${profile_file}"
done < <(find /config/.local/share/konsole -maxdepth 1 -type f -name '*.profile' 2>/dev/null | sort)

profile_appearance_key() {
  local key="$1"
  local candidate value
  for candidate in "${profile_candidates[@]}"; do
    value="$(read_ini_value "${candidate}" "Appearance" "${key}" || true)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  done
}

pick_nerd_font() {
  command -v fc-match >/dev/null 2>&1 || return 0

  local pattern family first_family
  for pattern in \
    "JetBrainsMono Nerd Font Mono" \
    "JetBrainsMonoNL Nerd Font Mono" \
    "MesloLGS NF" \
    "FiraCode Nerd Font Mono" \
    "CaskaydiaCove Nerd Font Mono" \
    "Hack Nerd Font Mono" \
    "Symbols Nerd Font Mono"; do
    family="$(fc-match -f '%{family}\n' "${pattern}" 2>/dev/null | head -n 1 || true)"
    first_family="${family%%,*}"
    case "${family}" in
      *Nerd*|*NFM*|*MesloLGS*|*FiraCode*|*Caskaydia*|*JetBrainsMono*|*Symbols*)
        printf '%s,10,-1,5,50,0,0,0,0,0\n' "${first_family}"
        return 0
        ;;
    esac
  done
}

appearance_color_scheme="$(profile_appearance_key "ColorScheme" || true)"
appearance_color_scheme="${appearance_color_scheme:-kubuntu-black}"
appearance_font="$(profile_appearance_key "Font" || true)"
appearance_font="${appearance_font:-$(pick_nerd_font)}"
appearance_antialias="$(profile_appearance_key "AntiAliasFonts" || true)"
appearance_bold_intense="$(profile_appearance_key "BoldIntenseCharacters" || true)"
appearance_line_chars="$(profile_appearance_key "UseFontLineCharacters" || true)"
appearance_line_spacing="$(profile_appearance_key "LineSpacing" || true)"

write_appearance_section() {
  printf '[Appearance]\n'
  printf 'ColorScheme=%s\n' "${appearance_color_scheme}"
  [[ -n "${appearance_font}" ]] && printf 'Font=%s\n' "${appearance_font}"
  [[ -n "${appearance_antialias}" ]] && printf 'AntiAliasFonts=%s\n' "${appearance_antialias}"
  [[ -n "${appearance_bold_intense}" ]] && printf 'BoldIntenseCharacters=%s\n' "${appearance_bold_intense}"
  [[ -n "${appearance_line_chars}" ]] && printf 'UseFontLineCharacters=%s\n' "${appearance_line_chars}"
  [[ -n "${appearance_line_spacing}" ]] && printf 'LineSpacing=%s\n' "${appearance_line_spacing}"
  return 0
}

cat >/usr/local/bin/kde-host-terminal <<'HOSTTERM'
#!/usr/bin/env bash
set -euo pipefail

target="${HOST_SSH_TARGET:-}"
if [[ -z "${target}" ]]; then
  target="${HOST_USER:?HOST_USER is required}@${HOST_SSH_HOST:-host.docker.internal}"
fi

port="${HOST_SSH_PORT:-22}"
key="${HOST_SSH_KEY:-/config/.ssh/kde-webtop-host-ed25519}"
remote_cmd='cd "$HOME" || exit; export KDE_WEBTOP_CONTEXT=HOST; exec bash -i'

printf '\033]0;HOST SSH %s\007' "${target}"
printf '\033[1;33mHOST SSH terminal -> %s:%s\033[0m\n' "${target}" "${port}"
ssh_args=(
  -tt
  -p "${port}"
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=3
  -o StrictHostKeyChecking=accept-new
)

if [[ -f "${key}" ]]; then
  ssh_args+=(
    -i "${key}"
    -o IdentitiesOnly=yes
    -o PreferredAuthentications=publickey
    -o PasswordAuthentication=no
  )
else
  printf '\033[1;31mSSH key missing: %s\033[0m\n' "${key}" >&2
  printf 'Run scripts/setup-host-ssh-key.sh on the Docker host, then reopen this terminal.\n' >&2
  exit 1
fi

exec ssh "${ssh_args[@]}" "${target}" "${remote_cmd}"
HOSTTERM

cat >/usr/local/bin/kde-docker-terminal <<'DOCKERTERM'
#!/usr/bin/env bash
set -euo pipefail

cd /config
export KDE_WEBTOP_CONTEXT=DOCKER
container_user="${CONTAINER_USER:-$(id -un 2>/dev/null || echo docker)}"
export USER="${container_user}"
export LOGNAME="${container_user}"
printf '\033]0;DOCKER local terminal\007'
printf '\033[1;36mDOCKER local terminal -> %s\033[0m\n' "$(hostname)"
exec bash -i
DOCKERTERM

chmod 755 /usr/local/bin/kde-host-terminal /usr/local/bin/kde-docker-terminal

{
  write_appearance_section
  cat <<EOF

[General]
Command=/usr/local/bin/kde-host-terminal
Icon=network-server
Name=Host SSH (${host_ssh_target})
Parent=FALLBACK/
TerminalMargin=3

[Scrolling]
HistorySize=10000
EOF
} >/config/.local/share/konsole/Host-SSH.profile

{
  write_appearance_section
  cat <<EOF

[General]
Command=/usr/local/bin/kde-docker-terminal
Icon=utilities-terminal
Name=Docker Terminal (${container_user:-container})
Parent=FALLBACK/
TerminalMargin=3

[Scrolling]
HistorySize=10000
EOF
} >/config/.local/share/konsole/Docker-Local.profile

cat >/config/.local/share/applications/kde-host-terminal.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Host SSH Terminal
Comment=Open an SSH terminal on ${host_ssh_target}
Exec=konsole --profile /config/.local/share/konsole/Host-SSH.profile
Icon=network-server
Terminal=false
Categories=System;TerminalEmulator;
EOF

cat >/config/.local/share/applications/kde-docker-terminal.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Docker Terminal
Comment=Open a local shell inside the desktop container
Exec=konsole --profile /config/.local/share/konsole/Docker-Local.profile
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
EOF

cp /config/.local/share/applications/kde-host-terminal.desktop "/config/Desktop/Host SSH Terminal.desktop"
cp /config/.local/share/applications/kde-docker-terminal.desktop "/config/Desktop/Docker Terminal.desktop"
chmod 755 "/config/Desktop/Host SSH Terminal.desktop" "/config/Desktop/Docker Terminal.desktop"

chown -R abc:abc /config/Desktop /config/.config /config/.local

if command -v kwriteconfig6 >/dev/null 2>&1; then
  s6-setuidgid abc env HOME=/config XDG_CONFIG_HOME=/config/.config \
    kwriteconfig6 --file /config/.config/konsolerc \
    --group "Desktop Entry" \
    --key DefaultProfile "Host-SSH.profile"
else
  if ! grep -q '^\[Desktop Entry\]' /config/.config/konsolerc 2>/dev/null; then
    printf '\n[Desktop Entry]\n' >>/config/.config/konsolerc
  fi
  sed -i '/^DefaultProfile=/d' /config/.config/konsolerc
  sed -i '/^\[Desktop Entry\]/a DefaultProfile=Host-SSH.profile' /config/.config/konsolerc
fi

echo "[terminal-integration] Host terminal target: ${host_ssh_target}:${host_ssh_port}"
echo "[terminal-integration] Host SSH key: ${HOST_SSH_KEY:-/config/.ssh/kde-webtop-host-ed25519}"
echo "[terminal-integration] Docker terminal user: ${container_user:-abc}"
