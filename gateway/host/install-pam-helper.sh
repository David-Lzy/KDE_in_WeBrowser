#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

if [[ ! -f /usr/include/security/pam_appl.h ]]; then
  echo "missing PAM headers; install libpam0g-dev first" >&2
  exit 1
fi

install -d -m 755 /usr/local/libexec /run/kde-webtop-pam /etc/systemd/system

cc -O2 -Wall -Wextra \
  -o /usr/local/libexec/kde-webtop-pam-check \
  "$(dirname "$0")/kde-webtop-pam-check.c" \
  -lpam

install -m 755 \
  "$(dirname "$0")/kde-webtop-pam-helper-server.py" \
  /usr/local/libexec/kde-webtop-pam-helper-server

cat >/etc/systemd/system/kde-webtop-pam-helper.service <<'UNIT'
[Unit]
Description=KDE Webtop PAM helper socket server
After=network.target

[Service]
Type=simple
Environment=KDE_WEBTOP_PAM_SOCKET=/run/kde-webtop-pam/helper.sock
Environment=KDE_WEBTOP_PAM_SOCKET_GROUP=docker
ExecStart=/usr/local/libexec/kde-webtop-pam-helper-server
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now kde-webtop-pam-helper.service
systemctl status kde-webtop-pam-helper.service --no-pager -l
