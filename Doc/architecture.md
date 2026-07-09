# Architecture Notes

The project is organized around a browser-accessible KDE desktop with optional
application modules.

## Base Desktop

The current base desktop template uses LinuxServer Webtop:

- image: `lscr.io/linuxserver/webtop:ubuntu-kde`
- browser transport: Selkies on internal ports `3000` and `3001`
- desktop mode: KDE Wayland with Xwayland support
- GPU path: `/dev/dri` plus NVIDIA runtime on hosts that provide it

The Compose template lives at `compose/webtop-kde.yml`.

The browser entrypoint is `gateway-nginx`, which is published on the host and
uses `auth_request` against Authelia. Raw Webtop ports are not published by
default. The same NGINX container also provides a TLS listener on `8443` for
host and frpc HTTPS exposure.

## Init Extensions

Custom init scripts are mounted into `/custom-cont-init.d`:

- `50-xwayland-clipboard-bridge.sh` keeps text clipboard content synchronized
  between native Wayland applications and Xwayland applications.
- `55-kde-session-prefs.sh` writes KDE locale/session defaults from the host
  user's language and installs the KDE scale sync command used by Selkies.
- `60-auto-hidpi-dpi.sh` injects client-side DPI selection so Selkies can map
  browser device pixel ratio to a matching stream DPI and KDE scale state.

## Optional Modules

`modules/wechat-qq/` stores the image layer, launcher scripts, and defaults for
the WeChat/QQ desktop module.

`modules/frpc/` stores sanitized frpc examples for publishing the authenticated
gateway through a remote frps server. Real frpc tokens and server details are
local deployment data and are intentionally excluded from Git.
