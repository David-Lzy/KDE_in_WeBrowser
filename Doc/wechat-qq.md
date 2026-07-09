# WeChat/QQ Module

The WeChat/QQ module is part of the main Webtop image layer.

Build it with:

```bash
docker compose --env-file .env \
  -f compose/webtop-kde.yml \
  up -d --build
```

The main Compose file builds `modules/wechat-qq/Dockerfile`, which extends the
KDE Webtop base image and copies the installed WeChat/QQ application trees from
`ghcr.io/nickrunning/wechat-selkies:latest` by default. This keeps the app
versions close to the original prototype and avoids downloading newer app
packages during every build.

## Environment

- `ENABLE_WECHAT_QQ_MODULE`: default `true`.
- `INSTALL_WECHAT`: build-time default `true`.
- `INSTALL_QQ`: build-time default `true`.
- `INSTALL_PCMANFM`: build-time default `true`.
- `AUTO_START_WECHAT`: runtime default `false`.
- `AUTO_START_QQ`: runtime default `false`.

## Data Mapping

The module does not include user data. Provide your own host directories:

- `WECHAT_PROFILE_DIR`: mounted to `/config/.xwechat`.
- `WECHAT_FILES_DIR`: mounted to `/wechat-xwechat-files` and linked to
  `/config/Documents/xwechat_files`, which is the path the Linux WeChat client
  reads.
- `QQ_DATA_DIR`: mounted to `/config/Tencent Files`.

Default mappings are under the project-local ignored `data/` directory:

```text
data/wechat/.xwechat
data/wechat/xwechat_files
data/qq/Tencent Files
```

Do not commit these paths. They may contain account data, chat data, and file
transfers.

For migration from an existing `wechat-selkies` deployment, stop the webtop
container, move the old data into the ignored project-local `data/` directory,
then point `.env` at the new absolute paths:

```env
WECHAT_PROFILE_DIR=/path/to/KDE_in_WeBrowser/data/wechat/.xwechat
WECHAT_FILES_DIR=/path/to/KDE_in_WeBrowser/data/wechat/xwechat_files
```
