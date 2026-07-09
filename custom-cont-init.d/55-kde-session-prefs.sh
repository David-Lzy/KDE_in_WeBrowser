#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_KDE_SESSION_PREFS:-true}" != "true" ]]; then
  echo "[kde-session-prefs] Disabled"
  exit 0
fi

lang="${WEBTOP_LANG:-${LANG:-${LC_ALL:-zh_CN.UTF-8}}}"
language="${WEBTOP_LANGUAGE:-${LANGUAGE:-}}"
lc_all="${WEBTOP_LC_ALL:-${LC_ALL:-${lang}}}"

if [[ -z "${language}" || "${language}" == "C" || "${language}" == "POSIX" ]]; then
  language="${lang%%.*}"
  language="${language%%@*}"
fi
language="${language%%.*}"

html_lang="${language%%:*}"
html_lang="${html_lang/_/-}"

export HOME=/config
export XDG_CONFIG_HOME=/config/.config
export XDG_DATA_HOME=/config/.local/share
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/config/.XDG}"
export LANG="${lang}"
export LANGUAGE="${language}"
export LC_ALL="${lc_all}"

install -d -m 755 /usr/local/bin /config/.config /config/.local/state/kde-webtop

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file plasma-localerc --group Formats --key LANG "${lang}" || true
  kwriteconfig6 --file plasma-localerc --group Translations --key LANGUAGE "${language}" || true
else
  cat > /config/.config/plasma-localerc <<EOF
[Formats]
LANG=${lang}

[Translations]
LANGUAGE=${language}
EOF
fi

cat >/usr/local/bin/kde-webtop-scale-sync <<'SCALESYNC'
#!/usr/bin/env bash
set -euo pipefail

dpi="${1:-}"
if [[ ! "${dpi}" =~ ^[0-9]+$ ]]; then
  echo "usage: kde-webtop-scale-sync <dpi>" >&2
  exit 2
fi

scale="$(
  awk -v dpi="${dpi}" 'BEGIN {
    scale = dpi / 96
    if (scale < 1) {
      scale = 1
    }
    if (scale > 3) {
      scale = 3
    }
    printf "%.2f", scale
  }'
)"

export HOME="${HOME:-/config}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/config/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/config/.XDG}"

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kwinrc --group Xwayland --key Scale "${scale}" || true
  kwriteconfig6 --file kdeglobals --group KScreen --key ScaleFactor "${scale}" || true
fi

mkdir -p /config/.local/state/kde-webtop
cat >/config/.local/state/kde-webtop/scale <<EOF
dpi=${dpi}
scale=${scale}
EOF

echo "[kde-scale-sync] applied dpi=${dpi} scale=${scale}"
SCALESYNC
chmod 755 /usr/local/bin/kde-webtop-scale-sync

cat >/usr/local/bin/kde-webtop-session-sync <<'SESSIONSYNC'
#!/usr/bin/env bash
set -euo pipefail

restart_plasma=false
for arg in "$@"; do
  case "${arg}" in
    --restart-plasma)
      restart_plasma=true
      ;;
    --no-restart-plasma)
      restart_plasma=false
      ;;
    -h|--help)
      echo "usage: kde-webtop-session-sync [--restart-plasma]" >&2
      exit 0
      ;;
    *)
      echo "unknown argument: ${arg}" >&2
      exit 2
      ;;
  esac
done

run_if_present() {
  local script="$1"
  if [[ -x "${script}" ]]; then
    "${script}"
  fi
}

run_if_present /custom-cont-init.d/55-kde-session-prefs.sh
run_if_present /custom-cont-init.d/60-auto-hidpi-dpi.sh
run_if_present /custom-cont-init.d/65-theme-sync.sh

theme_mode="$(
  if command -v kde-webtop-theme-sync >/dev/null 2>&1; then
    kde-webtop-theme-sync status 2>/dev/null || true
  fi
)"
case "${theme_mode}" in
  dark|light)
    kde-webtop-theme-sync "${theme_mode}" || true
    ;;
esac

dpi="$(
  awk -F= '$1 == "dpi" { print $2 }' /config/.local/state/kde-webtop/scale 2>/dev/null \
    | tail -n 1
)"
if [[ -z "${dpi}" ]]; then
  dpi=96
fi
if command -v kde-webtop-scale-sync >/dev/null 2>&1; then
  kde-webtop-scale-sync "${dpi}" || true
fi

if [[ "${restart_plasma}" == "true" ]]; then
  uid="$(id -u abc 2>/dev/null || echo 1000)"
  pkill -TERM -u "${uid}" -x plasmashell 2>/dev/null || true
  sleep 5
  if ! pgrep -u "${uid}" -x plasmashell >/dev/null 2>&1; then
    container_user="${CONTAINER_USER:-${HOST_USER:+docker_${HOST_USER}}}"
    export HOME=/config
    export XDG_CONFIG_HOME=/config/.config
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/config/.XDG}"
    export DISPLAY="${DISPLAY:-:1}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
    export LANG="${WEBTOP_LANG:-${LANG:-zh_CN.UTF-8}}"
    export LANGUAGE="${WEBTOP_LANGUAGE:-${LANGUAGE:-zh_CN}}"
    export LC_ALL="${WEBTOP_LC_ALL:-${LC_ALL:-${LANG}}}"
    export USER="${container_user:-docker}"
    export LOGNAME="${container_user:-docker}"
    s6-setuidgid abc env \
      HOME="${HOME}" \
      XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
      XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
      DISPLAY="${DISPLAY}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY}" \
      QT_QPA_PLATFORM="${QT_QPA_PLATFORM}" \
      LANG="${LANG}" \
      LANGUAGE="${LANGUAGE}" \
      LC_ALL="${LC_ALL}" \
      USER="${USER}" \
      LOGNAME="${LOGNAME}" \
      plasmashell >>/config/log/plasmashell-reload.log 2>&1 &
    echo "[session-sync] started plasmashell manually"
  else
    echo "[session-sync] plasmashell restarted by supervisor"
  fi
fi

echo "[session-sync] applied restart_plasma=${restart_plasma}"
SESSIONSYNC
chmod 755 /usr/local/bin/kde-webtop-session-sync

for webroot in /usr/share/selkies/selkies-dashboard /usr/share/selkies/selkies-dashboard-wish /usr/share/selkies/web; do
  index="${webroot}/index.html"
  [[ -f "${index}" ]] || continue
  sed -i -E "s#<html lang=\"[^\"]*\"#<html lang=\"${html_lang}\"#" "${index}"
done

cat >/config/.local/state/kde-webtop/locale <<EOF
LANG=${lang}
LANGUAGE=${language}
LC_ALL=${lc_all}
HTML_LANG=${html_lang}
EOF

chown -R abc:abc /config/.config /config/.local/state/kde-webtop
echo "[kde-session-prefs] locale=${lang} language=${language} html_lang=${html_lang}"
