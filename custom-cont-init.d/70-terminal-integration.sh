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
  /config/.local/share/applications /config/.local/share/konsole

cat >/usr/local/bin/kde-host-terminal <<'HOSTTERM'
#!/usr/bin/env bash
set -euo pipefail

target="${HOST_SSH_TARGET:-}"
if [[ -z "${target}" ]]; then
  target="${HOST_USER:?HOST_USER is required}@${HOST_SSH_HOST:-host.docker.internal}"
fi

port="${HOST_SSH_PORT:-22}"
remote_cmd='cd "$HOME"; export KDE_WEBTOP_CONTEXT=HOST; export PS1="\[\e[1;33m\][HOST \u@\h \W]\$ \[\e[0m\]"; exec bash --noprofile --norc -i'

printf '\033]0;HOST SSH %s\007' "${target}"
printf '\033[1;33mHOST SSH terminal -> %s:%s\033[0m\n' "${target}" "${port}"
exec ssh -tt \
  -p "${port}" \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o StrictHostKeyChecking=accept-new \
  "${target}" \
  "${remote_cmd}"
HOSTTERM

cat >/usr/local/bin/kde-docker-terminal <<'DOCKERTERM'
#!/usr/bin/env bash
set -euo pipefail

cd /config
export KDE_WEBTOP_CONTEXT=DOCKER
export PS1='\[\e[1;36m\][DOCKER \u@\h \W]\$ \[\e[0m\]'
printf '\033]0;DOCKER local terminal\007'
printf '\033[1;36mDOCKER local terminal -> %s\033[0m\n' "$(hostname)"
exec bash --noprofile --norc -i
DOCKERTERM

chmod 755 /usr/local/bin/kde-host-terminal /usr/local/bin/kde-docker-terminal

cat >/config/.local/share/konsole/Host-SSH.profile <<EOF
[Appearance]
ColorScheme=kubuntu-black

[General]
Command=/usr/local/bin/kde-host-terminal
Icon=network-server
Name=Host SSH (${host_ssh_target})
Parent=FALLBACK/
TerminalMargin=3

[Scrolling]
HistorySize=10000
EOF

cat >/config/.local/share/konsole/Docker-Local.profile <<EOF
[Appearance]
ColorScheme=kubuntu-black

[General]
Command=/usr/local/bin/kde-docker-terminal
Icon=utilities-terminal
Name=Docker Terminal (${container_user:-container})
Parent=FALLBACK/
TerminalMargin=3

[Scrolling]
HistorySize=10000
EOF

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
echo "[terminal-integration] Docker terminal user: ${container_user:-abc}"
