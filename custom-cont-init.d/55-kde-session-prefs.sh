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
