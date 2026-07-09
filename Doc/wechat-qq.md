# WeChat/QQ Module

The WeChat/QQ module is optional and disabled by default.

Enable it by adding the override file:

```bash
docker compose --env-file .env \
  -f compose/webtop-kde.yml \
  -f compose/wechat-qq.override.yml \
  up -d --build
```

The override builds `modules/wechat-qq/Dockerfile`, which extends the KDE
Webtop base image and installs WeChat, optional QQ, launcher scripts, and KDE
desktop shortcuts.

## Environment

- `ENABLE_WECHAT_QQ_MODULE`: default `true` in the override.
- `INSTALL_WECHAT`: build-time default `true`.
- `INSTALL_QQ`: build-time default `true`.
- `INSTALL_PCMANFM`: build-time default `true`.
- `AUTO_START_WECHAT`: runtime default `false`.
- `AUTO_START_QQ`: runtime default `false`.

## Data Mapping

The module does not include user data. Provide your own host directories:

- `WECHAT_PROFILE_DIR`: mounted to `/config/.xwechat`.
- `WECHAT_FILES_DIR`: mounted to `/config/xwechat_files`.
- `QQ_DATA_DIR`: mounted to `/config/Tencent Files`.

Default mappings are under `${HOST_HOME}`:

```text
${HOST_HOME}/.xwechat
${HOST_HOME}/xwechat_files
${HOST_HOME}/Tencent Files
```

Do not commit these paths. They may contain account data, chat data, and file
transfers.
