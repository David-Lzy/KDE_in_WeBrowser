# Configuration

Most deployment behavior is controlled by `.env`. The Compose template stays
generic; the wizard and helper scripts generate local values for the current
host.

## Files

- `.env`: main local configuration file. It is ignored by Git.
- `compose.local.yml`: optional structural override, usually only for extra bind
  mounts. It is ignored by Git.
- `modules/frpc/frpc.toml`: optional private frpc config. It is ignored by Git.
- `data/`: default project-local runtime state, desktop home, WeChat/QQ data,
  Authelia config, Baota render output, and generated assets.

## Important Groups

- Compose identity: `COMPOSE_PROJECT_NAME`, `CONTAINER_NAME`,
  `CONTAINER_HOSTNAME`.
- Host user: `HOST_USER`, `HOST_UID`, `HOST_GID`, `HOST_HOME`,
  `CONTAINER_USER`.
- Gateway: `GATEWAY_BIND`, `GATEWAY_PORT`, `GATEWAY_PUBLIC_BASE_URL`,
  `GATEWAY_AUTH_PROVIDER`, `GATEWAY_TLS_CERT`, `GATEWAY_TLS_KEY`.
- Selkies: clipboard, encoder, bitrate, framerate, DPI, and scaling variables.
- Terminal integration: `ENABLE_TERMINAL_INTEGRATION`, `HOST_SSH_*`, terminal
  font/config sync settings.
- WeChat/QQ: install toggles, autostart toggles, and data directories.
- Exposure: `EXPOSURE_METHOD`, frpc config path, Cloudflare Tunnel values, and
  public ACME values.

## Compose Profiles

- default: Webtop, gateway, and authentication services.
- `frpc`: optional frpc client.
- `cloudflare`: Cloudflare named tunnel.
- `cloudflare-quick`: temporary Cloudflare quick tunnel.

Use profiles only for the exposure method you actually configured.

## Editing Rules

Routine configuration belongs in `.env`. Use `compose.local.yml` only when the
Compose structure itself must change, such as extra host mounts. Do not put
tokens, passwords, private keys, or personal app data into tracked files.
