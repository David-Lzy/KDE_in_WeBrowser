# Compose Templates

This directory contains reusable Docker Compose templates for the project.

## KDE Webtop

Copy the sample environment file and set a private password before deployment:

```bash
scripts/detect-host-user.sh "$USER" > .env
$EDITOR .env
docker compose --env-file .env -f compose/webtop-kde.yml up -d
```

The template exposes LinuxServer Webtop KDE on:

- HTTP: `127.0.0.1:18023`
- HTTPS: `127.0.0.1:18024`

Use HTTPS for normal browser access. Selkies features used by the desktop work
best in a secure browser context.

Runtime state is written to `${HOST_HOME}` by default because that path is
mounted as `/config`. This is personal-home mode: KDE config, desktop files,
downloads, and application state can be created in the selected host user's
home directory.

LinuxServer containers warn when mounted custom init files are writable by the
non-root checkout user. Before a production deployment, make a root-owned copy
or adjust ownership on the deployed `custom-cont-init.d/` directory:

```bash
sudo chown -R root:root custom-cont-init.d
sudo chmod 755 custom-cont-init.d custom-cont-init.d/*.sh
```

Bandwidth-related Selkies controls are exposed through `.env`:

- `SELKIES_ENCODER`
- `SELKIES_FRAMERATE`
- `SELKIES_VIDEO_BITRATE`
- `SELKIES_RATE_CONTROL_MODE`
- `SELKIES_ENABLE_RATE_CONTROL`
- `SELKIES_H264_CRF`
- `SELKIES_JPEG_QUALITY`
- `SELKIES_AUDIO_BITRATE`
- `SELKIES_USE_PAINT_OVER_QUALITY`
- `SELKIES_PAINT_OVER_JPEG_QUALITY`
- `SELKIES_H264_PAINTOVER_CRF`
- `SELKIES_H264_PAINTOVER_BURST_FRAMES`

Preset files are available at the repository root:

- `.env.low-bandwidth.example`
- `.env.balanced.example`
- `.env.quality.example`

Terminal-related controls:

- `ENABLE_TERMINAL_INTEGRATION`
- `HOST_SSH_HOST`
- `HOST_SSH_PORT`
- `HOST_SSH_TARGET`

Theme sync controls:

- `ENABLE_THEME_SYNC`
- `THEME_SYNC_LIGHT_SCHEME`
- `THEME_SYNC_DARK_SCHEME`
- `THEME_SYNC_LIGHT_LOOK_AND_FEEL`
- `THEME_SYNC_DARK_LOOK_AND_FEEL`
- `SELKIES_COMMAND_ENABLED`

Optional WeChat/QQ module controls, used with `compose/wechat-qq.override.yml`:

- `ENABLE_WECHAT_QQ_MODULE`
- `INSTALL_WECHAT`
- `INSTALL_QQ`
- `INSTALL_PCMANFM`
- `AUTO_START_WECHAT`
- `AUTO_START_QQ`
- `WECHAT_PROFILE_DIR`
- `WECHAT_FILES_DIR`
- `QQ_DATA_DIR`

Gateway-related controls:

- `GATEWAY_BIND`
- `GATEWAY_PORT`
- `GATEWAY_PUBLIC_BASE_URL`
- `GATEWAY_COOKIE_SECRET`
- `BETTER_AUTH_SECRET`
- `GATEWAY_SESSION_MAX_AGE_SECONDS`
- `GATEWAY_COOLDOWN_WINDOW_SECONDS`
- `GATEWAY_COOLDOWN_MAX_FAILURES`
- `GATEWAY_COOLDOWN_LOCK_SECONDS`
- `PAM_HELPER_SOCKET`

frpc is disabled by default. To enable it, copy
`modules/frpc/frpc.example.toml` to `modules/frpc/frpc.toml`, fill in secrets
locally, then run with `--profile frpc`.
