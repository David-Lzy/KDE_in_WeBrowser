# WeChat/QQ Module Assets

This directory contains reusable startup scripts and Openbox defaults imported
from the local `wechat-selkies` prototype.

Included assets:

- `root/scripts/start.sh`
- `root/scripts/refresh-menu.sh`
- `root/scripts/window_switcher.py`
- `root/scripts/wechat/`
- `root/scripts/qq/`
- `root/defaults/`

These files are used by the main image layer to provide WeChat and QQ desktop
launchers inside a Selkies/Webtop-style browser desktop. The Dockerfile copies
the installed WeChat/QQ application trees from
`ghcr.io/nickrunning/wechat-selkies:latest` by default so the app versions stay
close to the original prototype.

Not included:

- `.env`
- real frpc config
- `/config`
- WeChat/QQ profile and chat data
- upstream Git metadata

## Enable

Build and run the main Compose file:

```bash
docker compose --env-file .env \
  -f compose/webtop-kde.yml \
  up -d --build
```

Use `.env` to control `INSTALL_WECHAT`, `INSTALL_QQ`, `INSTALL_PCMANFM`,
`AUTO_START_WECHAT`, and `AUTO_START_QQ`.
