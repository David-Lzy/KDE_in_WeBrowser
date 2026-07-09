# KDE in Web Browser

Personal browser-accessible Linux desktop built around KDE Wayland, Docker,
Selkies/Webtop, host-user integration, and an optional WeChat/QQ module.

## Current Contents

- `compose/webtop-kde.yml`: reusable LinuxServer Webtop KDE Compose template.
- `custom-cont-init.d/`: Selkies/KDE init extensions for clipboard and HiDPI.
- `modules/wechat-qq/`: optional WeChat/QQ launcher assets.
- `modules/frpc/`: sanitized frpc examples.
- `Doc/`: public project documentation.

## Quick Start

```bash
scripts/install.sh --preset balanced
docker compose --env-file .env -f compose/webtop-kde.yml -f compose.local.yml up -d
```

Set a private `PASSWORD` in `.env` before exposing the desktop beyond localhost.
By default, the selected host user's home directory is mounted as `/config`,
so KDE state and desktop files are written into that host home.

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
