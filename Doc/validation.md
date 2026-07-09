# Validation

Run this before publishing a change:

```bash
scripts/validate.sh
```

The script checks shell, Python, gateway Node syntax, npm audit, Compose
rendering, bandwidth presets, NGINX gateway config, installer smoke behavior,
and public-safe path and secret scans. It does not start or stop the desktop.

To include checks against an already running local deployment:

```bash
VALIDATE_LIVE=1 scripts/validate.sh
```

`VALIDATE_LIVE=1` requires `.env` and `compose.local.yml`. It checks the Compose
state, gateway health endpoint, and that unauthenticated HTTP and WebSocket
requests are redirected to login.

## Manual Browser Checklist

Use the gateway URL from `.env`, usually `http://127.0.0.1:18080`.

| Scenario | Expected result |
| --- | --- |
| Gateway login success | Correct host username/password enters the desktop. |
| Gateway wrong password | Login returns an invalid credentials error. |
| Repeated wrong password cooldown | After the configured failure count, login returns cooldown. |
| Unauthenticated Webtop HTTP blocked | Opening `/` without a session redirects to `/auth/login`. |
| Unauthenticated WebSocket blocked | A direct WebSocket upgrade without a session redirects or fails auth. |
| KDE starts | KDE Plasma desktop reaches an interactive state. |
| Wayland/Xwayland available | Native KDE apps and Xwayland apps can both launch. |
| Clipboard browser to KDE | Text copied in the browser can paste into KDE. |
| Clipboard KDE to browser | Text copied in KDE can paste into the browser. |
| Browser resize changes remote canvas | Resizing the browser updates the remote desktop canvas. |
| HiDPI DPI sync works | DPI changes follow the browser size/pixel-ratio policy. |
| Theme sync works | Browser dark/light preference changes KDE Breeze dark/light. |
| Host terminal opens host shell | Host SSH profile opens the configured host shell. |
| Docker terminal opens container shell | Docker profile opens a shell inside the webtop container. |
| WeChat/QQ optional module launches when enabled | Desktop shortcuts launch enabled apps and data maps to `/config`. |
| frpc optional module exposes only gateway when enabled | frpc points at `gateway-nginx:8080`, not raw Webtop ports. |

## Release Gate

Before a public push, also check:

```bash
git status --short
git diff --check
git ls-files
```

The public file set must not include `.env`, `.agent/`, `.local/`, `_incoming/`,
runtime `config/`, WeChat/QQ data, real `frpc.toml`, tokens, TLS private keys,
or large runtime files.
