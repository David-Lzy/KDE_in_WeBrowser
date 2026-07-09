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

These files are intended for an optional image layer that provides WeChat and
QQ desktop launchers inside a Selkies/Webtop-style browser desktop.

Not included:

- `.env`
- real frpc config
- `/config`
- WeChat/QQ profile and chat data
- upstream Git metadata

## Enable

Use the Compose override:

```bash
docker compose --env-file .env \
  -f compose/webtop-kde.yml \
  -f compose/wechat-qq.override.yml \
  up -d --build
```

The module remains disabled unless this override is included.
