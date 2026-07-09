# Compose Templates

This directory contains reusable Docker Compose templates for the project.

## KDE Webtop

Generate local deployment files and start the stack:

```bash
scripts/configure-deployment.sh
```

For a minimal scripted setup:

```bash
scripts/install.sh --preset balanced
docker compose --env-file .env -f compose/webtop-kde.yml -f compose.local.yml up -d
```

The template publishes only the TLS listener of `gateway-nginx`, normally on
`https://127.0.0.1:18080`. LinuxServer Webtop KDE stays inside the Docker
network on ports `3000` and `3001`. NGINX protects Webtop with `auth_request`
and then proxies authenticated traffic to it. The default provider is the
host-side PAM auth helper; Authelia remains available as an optional fallback.
NGINX keeps container-local HTTP on `8080`, but that port is not published to
the host.

Runtime state is written to `${HOST_HOME}` because that path is mounted as
`/config`. The installer sets it to a project-local directory under
`data/home/<user>` so KDE config, desktop files, downloads, and application
state stay inside this project tree.

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
- `HOST_SSH_KEY`

Host/user identity controls:

- `CONTAINER_USER`
- `CONTAINER_HOSTNAME`

Theme sync controls:

- `ENABLE_THEME_SYNC`
- `THEME_SYNC_LIGHT_SCHEME`
- `THEME_SYNC_DARK_SCHEME`
- `THEME_SYNC_LIGHT_LOOK_AND_FEEL`
- `THEME_SYNC_DARK_LOOK_AND_FEEL`
- `SELKIES_COMMAND_ENABLED`

WeChat/QQ module controls:

- `ENABLE_WECHAT_QQ_MODULE`
- `INSTALL_WECHAT`
- `INSTALL_QQ`
- `INSTALL_PCMANFM`
- `AUTO_START_WECHAT`
- `AUTO_START_QQ`
- `WECHAT_PROFILE_DIR`
- `WECHAT_FILES_DIR`
- `QQ_DATA_DIR`

Gateway and Authelia controls:

- `GATEWAY_BIND`
- `GATEWAY_PORT`
- `GATEWAY_PUBLIC_BASE_URL`
- `GATEWAY_AUTH_PROVIDER`
- `GATEWAY_AUTH_INTERNAL_URI`
- `GATEWAY_TLS_CERT`
- `GATEWAY_TLS_KEY`
- `GATEWAY_TLS_SANS`

PAM auth helper controls:

- `PAM_AUTH_RUN_DIR`
- `PAM_AUTH_STATE_DIR`
- `PAM_AUTH_SOCKET_CONTAINER`
- `PAM_AUTH_SERVICE`
- `PAM_AUTH_ALLOWED_USERS`
- `PAM_AUTH_SESSION_TTL_SECONDS`
- `PAM_AUTH_COOKIE_NAME`

Authelia fallback controls:

- `AUTHELIA_VERSION`
- `AUTHELIA_CONFIG_DIR`
- `AUTHELIA_PUBLIC_BASE_URLS`
- `AUTHELIA_USER`
- `AUTHELIA_DISPLAY_NAME`
- `AUTHELIA_EMAIL`

frpc is disabled by default. To enable it, copy
`modules/frpc/frpc.example.toml` to `modules/frpc/frpc.toml`, fill in secrets
locally, then run with `--profile frpc`. The deployment wizard can also write
this file and sets `FRPC_CONFIG_FILE` in `.env` when a custom path is selected.
