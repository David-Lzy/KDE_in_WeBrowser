# Compose Templates

This directory contains reusable Docker Compose templates for the project.

## KDE Webtop

Generate local deployment files and start the stack:

```bash
scripts/deployment/configure.sh
```

For a minimal scripted setup:

```bash
scripts/deployment/install.sh --preset balanced
docker compose --env-file .env -f compose/webtop-kde.yml up -d
```

Baota/BT Panel should use the generated pair:

```bash
scripts/deployment/actions/render-baota-compose.sh
docker compose --env-file data/baota/.env -f data/baota/docker-compose.yml up -d
```

The Baota Compose file keeps `${...}` placeholders and the generated
`data/baota/.env` contains the concrete values. Routine configuration should be
changed in `.env` or `data/baota/.env`; Compose overrides are only needed for
structural changes such as arbitrary extra bind mounts.

The template publishes only the TLS listener of `gateway-nginx`, normally on
`https://127.0.0.1:18080`. LinuxServer Webtop KDE stays inside the Docker
network on ports `3000` and `3001`. NGINX protects Webtop with `auth_request`
and then proxies authenticated traffic to it. The default provider is the
host-side PAM auth helper; Authelia remains available as an optional fallback.
In public ACME mode, Certbot standalone opens TCP port `80` temporarily outside
Docker during certificate issuance and renewal; Docker still publishes only the
HTTPS gateway.

Cloudflare Tunnel uses the internal NGINX HTTP listener
`http://gateway-nginx:8080` as its origin. That listener exists only on the
Docker network and should not be published to the host. It runs the same
PAM/Authelia auth gateway before proxying to Webtop.

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

Network detection metadata written by the wizard:

- `EXPOSURE_METHOD`
- `NETWORK_EXPOSURE`
- `NETWORK_EXPOSURE_REASON`
- `NETWORK_ROUTE_IPV4`
- `NETWORK_ROUTE_IFACE`
- `NETWORK_PUBLIC_IPV4`
- `NETWORK_PUBLIC_IP_SERVICE`
- `NETWORK_DEFAULT_SSLIP_DOMAIN`
- `NETWORK_PORT_80_STATE`
- `NETWORK_PORT_443_STATE`

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

Public ACME controls:

- `ACME_ENABLED`
- `ACME_PROVIDER`
- `ACME_DOMAIN`
- `ACME_EMAIL`
- `ACME_CERT_NAME`
- `ACME_HTTP_PORT`
- `ACME_STAGING`
- `ACME_ALLOW_NO_EMAIL`
- `ACME_AUTO_RENEW`

Cloudflare Tunnel controls:

- `CLOUDFLARED_IMAGE`
- `CLOUDFLARE_API_BASE_URL`
- `CLOUDFLARED_ORIGIN_URL`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_HOSTNAME`
- `CLOUDFLARE_TUNNEL_NAME`
- `CLOUDFLARE_TUNNEL_ID`
- `CLOUDFLARED_TUNNEL_TOKEN`
- `CLOUDFLARE_DNS_PROXIED`

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

Cloudflare named tunnel runs with `--profile cloudflare`. Cloudflare quick
tunnel runs with `--profile cloudflare-quick`. The deployment wizard can set
both modes, and `scripts/deployment/actions/setup-cloudflare-tunnel.sh` configures the named
tunnel through the Cloudflare API.
