# KDE in Web Browser

Personal browser-accessible Linux desktop built around KDE Wayland, Docker,
Selkies/Webtop, an Authelia-protected HTTPS gateway, host-user integration, and
optional WeChat/QQ and frpc modules.

## Current Contents

- `compose/webtop-kde.yml`: reusable LinuxServer Webtop KDE Compose template.
- `custom-cont-init.d/`: Selkies/KDE init extensions for clipboard and HiDPI.
- `gateway/nginx/`: HTTPS reverse proxy and Authelia `auth_request` template.
- `modules/wechat-qq/`: WeChat/QQ image layer and launcher assets.
- `modules/frpc/`: sanitized frpc examples.
- `Doc/`: public project documentation.

## Quick Start

```bash
scripts/install.sh --preset balanced
AUTHELIA_BOOTSTRAP_PASSWORD='change-this' scripts/ensure-authelia-config.sh
docker compose --env-file .env -f compose/webtop-kde.yml -f compose.local.yml up -d
```

Open the gateway URL from `.env`, normally `https://127.0.0.1:18080`. The
gateway authenticates through Authelia. The raw Webtop ports are not published
by default.

The host-published gateway port maps to `gateway-nginx:8443`; container-local
HTTP on `8080` is not published. When frpc is enabled, expose
`gateway-nginx:8443` so the remote `18003` proxy is HTTPS. Local TLS material is
generated under ignored `ssl/` by
`scripts/ensure-gateway-tls.sh`.

By default, a project-local desktop home under `data/home/<user>` is mounted as
`/config`, so KDE state and desktop files stay inside this project directory.

Run the validation gate before publishing or after changing Compose/runtime
behavior:

```bash
scripts/validate.sh
```

This repository is intended to contain reusable code, templates, install
scripts, and public documentation only. Runtime state, host credentials,
frpc secrets, WeChat/QQ data, and local agent workflow notes are intentionally
kept out of Git.

Development is currently driven on `server2`. The active private work queue is
stored in `.local/Doc/` on that machine and is not part of the public repo.
