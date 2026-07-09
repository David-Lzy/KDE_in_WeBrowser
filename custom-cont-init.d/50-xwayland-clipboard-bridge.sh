#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_XWAYLAND_CLIPBOARD_BRIDGE,,}" != "true" ]]; then
  echo "[clipboard-bridge] Disabled"
  exit 0
fi

install -d -m 755 /usr/local/bin /config/log

cat >/usr/local/bin/xwayland-clipboard-bridge <<'BRIDGE'
#!/usr/bin/env bash
set -u

export HOME="${HOME:-/config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/config/.XDG}"
export WAYLAND_DISPLAY="${CLIPBOARD_BRIDGE_WAYLAND_DISPLAY:-wayland-0}"
export DISPLAY="${DISPLAY:-:0}"

wayland_socket="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
x_display_number="${DISPLAY#:}"
x_display_number="${x_display_number%%.*}"
x_socket="/tmp/.X11-unix/X${x_display_number}"

echo "[clipboard-bridge] Waiting for ${wayland_socket} and ${x_socket}"
until [[ -S "${wayland_socket}" && -S "${x_socket}" ]]; do
  sleep 1
done

echo "[clipboard-bridge] Started"
last_wayland=""
last_x11=""

while true; do
  wayland_text="$(timeout 1 wl-paste -n 2>/dev/null || true)"
  if [[ -n "${wayland_text}" && "${wayland_text}" != "${last_wayland}" && "${wayland_text}" != "${last_x11}" ]]; then
    printf '%s' "${wayland_text}" | xclip -selection clipboard 2>/dev/null || true
    last_wayland="${wayland_text}"
    last_x11="${wayland_text}"
  fi

  x11_text="$(timeout 1 xclip -selection clipboard -o 2>/dev/null || true)"
  if [[ -n "${x11_text}" && "${x11_text}" != "${last_x11}" && "${x11_text}" != "${last_wayland}" ]]; then
    printf '%s' "${x11_text}" | wl-copy 2>/dev/null || true
    last_x11="${x11_text}"
    last_wayland="${x11_text}"
  fi

  sleep 0.5
done
BRIDGE

chmod 755 /usr/local/bin/xwayland-clipboard-bridge
chown abc:abc /config/log

echo "[clipboard-bridge] Launching background bridge"
s6-setuidgid abc /usr/local/bin/xwayland-clipboard-bridge >>/config/log/xwayland-clipboard-bridge.log 2>&1 &
