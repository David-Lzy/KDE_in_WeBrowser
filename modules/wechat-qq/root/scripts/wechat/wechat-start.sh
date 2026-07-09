#!/bin/bash
set -e

export HOME="${HOME:-/config}"
export USER="${USER:-abc}"
export LOGNAME="${LOGNAME:-$USER}"
export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/config/.XDG}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

exec /usr/bin/wechat
