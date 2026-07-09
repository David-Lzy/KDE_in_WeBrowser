#!/usr/bin/with-contenv bash
set -euo pipefail

if [[ "${ENABLE_AUTO_HIDPI_DPI,,}" != "true" ]]; then
  echo "[auto-hidpi] Disabled"
  exit 0
fi

cat >/tmp/codex-auto-hidpi.js <<'AUTOHIDPI'
(function () {
  "use strict";

  var allowedDpis = [96, 120, 144, 168, 192, 216, 240, 264, 288];
  var lastDpi = null;
  var timer = null;
  var bootAttempts = 0;

  function nearestDpi(rawDpi) {
    var best = allowedDpis[0];
    var bestDelta = Math.abs(rawDpi - best);
    for (var i = 1; i < allowedDpis.length; i++) {
      var delta = Math.abs(rawDpi - allowedDpis[i]);
      if (delta < bestDelta) {
        best = allowedDpis[i];
        bestDelta = delta;
      }
    }
    return best;
  }

  function applyDpi(force) {
    var dpr = window.devicePixelRatio || 1;
    var targetDpi = nearestDpi(dpr * 96);
    if (!force && targetDpi === lastDpi) {
      return;
    }
    lastDpi = targetDpi;
    window.postMessage(
      { type: "settings", settings: { scaling_dpi: targetDpi } },
      window.location.origin
    );
    window.postMessage(
      { type: "command", value: "/usr/local/bin/kde-webtop-scale-sync " + targetDpi },
      window.location.origin
    );
    console.log("[auto-hidpi] devicePixelRatio=" + dpr + " scaling_dpi=" + targetDpi);
  }

  function schedule(force) {
    if (timer) {
      window.clearTimeout(timer);
    }
    timer = window.setTimeout(function () {
      applyDpi(!!force);
    }, 800);
  }

  window.addEventListener("resize", function () {
    schedule(false);
  });

  window.addEventListener("pageshow", function () {
    schedule(true);
  });

  document.addEventListener("visibilitychange", function () {
    if (!document.hidden) {
      schedule(true);
    }
  });

  window.setInterval(function () {
    applyDpi(false);
  }, 3000);

  var bootInterval = window.setInterval(function () {
    bootAttempts += 1;
    schedule(bootAttempts === 2);
    if (bootAttempts >= 4) {
      window.clearInterval(bootInterval);
    }
  }, 2500);

  schedule(true);
})();
AUTOHIDPI

asset_version="${KDE_WEBTOP_SYNC_ASSET_VERSION:-kde-sync-v1}"

for webroot in /usr/share/selkies/selkies-dashboard /usr/share/selkies/selkies-dashboard-wish /usr/share/selkies/web; do
  [[ -d "${webroot}" ]] || continue
  install -d -m 755 "${webroot}/src"
  install -m 644 /tmp/codex-auto-hidpi.js "${webroot}/src/codex-auto-hidpi.js"

  index="${webroot}/index.html"
  if [[ -f "${index}" ]]; then
    script_src="src/codex-auto-hidpi.js"
    if grep -q 'src="/src/' "${index}"; then
      script_src="/src/codex-auto-hidpi.js"
    fi
    script_tag="<script src=\"${script_src}?v=${asset_version}\"></script>"
    if grep -q "codex-auto-hidpi.js" "${index}"; then
      sed -i -E "s#<script src=\"/?src/codex-auto-hidpi.js[^\"]*\"></script>#${script_tag}#g" "${index}"
      echo "[auto-hidpi] Updated ${index}"
    else
      sed -i "s#</body>#${script_tag}</body>#" "${index}"
      echo "[auto-hidpi] Injected ${index}"
    fi
  fi
done
