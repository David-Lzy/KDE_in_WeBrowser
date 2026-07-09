#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_WECHAT_QQ_MODULE:-false}" != "true" ]]; then
  echo "[wechat-qq] Disabled"
  exit 0
fi

install -d -m 755 /config/Desktop /config/.local/share/applications /config/.config/autostart /config/log

container_user="${CONTAINER_USER:-${HOST_USER:+docker_${HOST_USER}}}"
container_user="${container_user:-abc}"

chmod 755 /scripts /scripts/wechat /scripts/qq 2>/dev/null || true

if [[ -d /wechat-xwechat-files ]]; then
  install -d -m 755 /config/Documents
  if [[ ! -e /config/Documents/xwechat_files || -L /config/Documents/xwechat_files ]]; then
    rm -f /config/Documents/xwechat_files
    ln -s /wechat-xwechat-files /config/Documents/xwechat_files
  fi
  if [[ -d /config/xwechat_files && ! -L /config/xwechat_files ]]; then
    backup="/config/xwechat_files.misplaced-$(date +%Y%m%d-%H%M%S)"
    mv /config/xwechat_files "${backup}"
    echo "[wechat-qq] Moved misplaced /config/xwechat_files to ${backup}"
  fi
  if [[ ! -e /config/xwechat_files || -L /config/xwechat_files ]]; then
    rm -f /config/xwechat_files
    ln -s /wechat-xwechat-files /config/xwechat_files
  fi
fi

launch_when_ready() {
  local name="$1"
  local launcher="$2"
  local match="$3"
  local log_file="$4"

  (
    for _ in $(seq 1 120); do
      if [[ -S /tmp/.X11-unix/X1 ]]; then
        break
      fi
      sleep 1
    done

    if [[ ! -S /tmp/.X11-unix/X1 ]]; then
      echo "[$(date -Is)] X display did not become ready for ${name}"
      exit 1
    fi

    sleep 3
    if pgrep -u abc -f "${match}" >/dev/null 2>&1; then
      echo "[$(date -Is)] ${name} already running"
      exit 0
    fi

    echo "[$(date -Is)] Starting ${name}"
    exec s6-setuidgid abc env \
      HOME=/config \
      USER="${container_user}" \
      LOGNAME="${container_user}" \
      DISPLAY=:1 \
      XDG_RUNTIME_DIR=/config/.XDG \
      WAYLAND_DISPLAY=wayland-0 \
      "${launcher}"
  ) >>"${log_file}" 2>&1 &
}

if [[ -x /scripts/wechat/wechat-start.sh ]]; then
  cat >/config/.local/share/applications/kde-webtop-wechat.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=WeChat
Comment=Launch WeChat inside KDE Webtop
Exec=/scripts/wechat/wechat-start.sh
Icon=wechat
Terminal=false
Categories=Network;Chat;
EOF
  cp /config/.local/share/applications/kde-webtop-wechat.desktop "/config/Desktop/WeChat.desktop"
  chmod 755 "/config/Desktop/WeChat.desktop"
  if [[ "${AUTO_START_WECHAT:-false}" == "true" ]]; then
    cp /config/.local/share/applications/kde-webtop-wechat.desktop /config/.config/autostart/kde-webtop-wechat.desktop
    launch_when_ready "WeChat" "/scripts/wechat/wechat-start.sh" "/opt/wechat|/usr/bin/wechat" "/config/log/wechat-autostart.log"
  fi
fi

if [[ -x /scripts/qq/qq-start.sh ]]; then
  cat >/config/.local/share/applications/kde-webtop-qq.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=QQ
Comment=Launch QQ inside KDE Webtop
Exec=/scripts/qq/qq-start.sh
Icon=qq
Terminal=false
Categories=Network;Chat;
EOF
  cp /config/.local/share/applications/kde-webtop-qq.desktop "/config/Desktop/QQ.desktop"
  chmod 755 "/config/Desktop/QQ.desktop"
  if [[ "${AUTO_START_QQ:-false}" == "true" ]]; then
    cp /config/.local/share/applications/kde-webtop-qq.desktop /config/.config/autostart/kde-webtop-qq.desktop
    launch_when_ready "QQ" "/scripts/qq/qq-start.sh" "/opt/QQ|/usr/bin/qq" "/config/log/qq-autostart.log"
  fi
fi

chown -R abc:abc /config/Desktop /config/.local /config/.config/autostart /config/log /config/Documents
echo "[wechat-qq] Shortcuts refreshed"
