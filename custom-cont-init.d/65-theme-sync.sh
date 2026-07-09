#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_THEME_SYNC:-true}" != "true" ]]; then
  echo "[theme-sync] Disabled"
  exit 0
fi

install -d -m 755 /usr/local/bin /config/log

cat >/usr/local/bin/kde-webtop-theme-sync <<'THEMESYNC'
#!/usr/bin/env bash
set -euo pipefail

mode="${1:-status}"
light_scheme="${THEME_SYNC_LIGHT_SCHEME:-BreezeLight}"
dark_scheme="${THEME_SYNC_DARK_SCHEME:-BreezeDark}"
light_look="${THEME_SYNC_LIGHT_LOOK_AND_FEEL:-org.kde.breeze.desktop}"
dark_look="${THEME_SYNC_DARK_LOOK_AND_FEEL:-org.kde.breezedark.desktop}"

export HOME="${HOME:-/config}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/config/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/config/.XDG}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  wayland_socket="$(find "${XDG_RUNTIME_DIR}" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | sort | head -n 1 || true)"
  if [[ -n "${wayland_socket}" ]]; then
    export WAYLAND_DISPLAY="${wayland_socket}"
  fi
fi
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"

apply_mode() {
  local target_mode="$1"
  local scheme look
  case "${target_mode}" in
    dark)
      scheme="${dark_scheme}"
      look="${dark_look}"
      ;;
    light)
      scheme="${light_scheme}"
      look="${light_look}"
      ;;
    *)
      echo "usage: kde-webtop-theme-sync [dark|light|toggle|status]" >&2
      return 2
      ;;
  esac

  if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
    plasma-apply-colorscheme "${scheme}" || true
  fi
  if command -v lookandfeeltool >/dev/null 2>&1; then
    lookandfeeltool -a "${look}" || true
  fi
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "${scheme}" || true
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "${look}" || true
  fi

  mkdir -p /config/.local/state/kde-webtop
  printf '%s\n' "${target_mode}" >/config/.local/state/kde-webtop/theme-mode
  echo "[theme-sync] applied ${target_mode} (${scheme})"
}

case "${mode}" in
  dark|light)
    apply_mode "${mode}"
    ;;
  toggle)
    current="light"
    if [[ -f /config/.local/state/kde-webtop/theme-mode ]]; then
      current="$(cat /config/.local/state/kde-webtop/theme-mode)"
    fi
    if [[ "${current}" == "dark" ]]; then
      apply_mode light
    else
      apply_mode dark
    fi
    ;;
  status)
    if [[ -f /config/.local/state/kde-webtop/theme-mode ]]; then
      cat /config/.local/state/kde-webtop/theme-mode
    else
      echo unknown
    fi
    ;;
  *)
    echo "usage: kde-webtop-theme-sync [dark|light|toggle|status]" >&2
    exit 2
    ;;
esac
THEMESYNC

chmod 755 /usr/local/bin/kde-webtop-theme-sync

cat >/tmp/codex-theme-sync.js <<'THEMEJS'
(function () {
  "use strict";

  var media = window.matchMedia("(prefers-color-scheme: dark)");
  var lastMode = null;
  var timer = null;

  function send(mode, force) {
    if (!force && mode === lastMode) {
      return;
    }
    lastMode = mode;
    window.postMessage(
      { type: "command", value: "/usr/local/bin/kde-webtop-theme-sync " + mode },
      window.location.origin
    );
    console.log("[theme-sync] requested " + mode);
  }

  function apply(force) {
    send(media.matches ? "dark" : "light", !!force);
  }

  function schedule(force) {
    if (timer) {
      window.clearTimeout(timer);
    }
    timer = window.setTimeout(function () {
      apply(force);
    }, 500);
  }

  if (typeof media.addEventListener === "function") {
    media.addEventListener("change", function () {
      schedule(true);
    });
  } else if (typeof media.addListener === "function") {
    media.addListener(function () {
      schedule(true);
    });
  }

  window.kdeWebtopThemeSync = {
    dark: function () { send("dark", true); },
    light: function () { send("light", true); },
    toggle: function () {
      var next = lastMode === "dark" ? "light" : "dark";
      send(next, true);
    },
    current: function () { return lastMode; }
  };

  window.addEventListener("pageshow", function () {
    schedule(true);
  });

  schedule(true);
})();
THEMEJS

for webroot in /usr/share/selkies/selkies-dashboard /usr/share/selkies/web; do
  [[ -d "${webroot}" ]] || continue
  install -d -m 755 "${webroot}/src"
  install -m 644 /tmp/codex-theme-sync.js "${webroot}/src/codex-theme-sync.js"

  index="${webroot}/index.html"
  if [[ -f "${index}" ]] && ! grep -q "codex-theme-sync.js" "${index}"; then
    sed -i 's#</body>#<script src="src/codex-theme-sync.js"></script></body>#' "${index}"
    echo "[theme-sync] Injected ${index}"
  fi
done

chown -R abc:abc /config/log
