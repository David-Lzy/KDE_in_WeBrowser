#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_WECHAT_QQ_MODULE:-false}" != "true" ]]; then
  echo "[wechat-qq] Disabled"
  exit 0
fi

install -d -m 755 /config/Desktop /config/.local/share/applications /config/.config/autostart

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
  fi
fi

chown -R abc:abc /config/Desktop /config/.local /config/.config/autostart
echo "[wechat-qq] Shortcuts refreshed"
