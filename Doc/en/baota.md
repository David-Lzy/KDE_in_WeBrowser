# Baota/BT Panel

Baota/BT Panel works better with a single Compose file and a complete env file.
The normal project layout keeps Compose reusable, so render a panel-specific
copy after `.env` is ready:

```bash
scripts/deployment/actions/render-baota-compose.sh
```

Generated files:

```text
data/baota/docker-compose.yml
data/baota/.env
```

Use those two files in Baota. The generated Compose file keeps service structure
in one place, while `data/baota/.env` contains concrete absolute paths and
deployment values.

## Profiles

Set `BAOTA_COMPOSE_PROFILES` before rendering when extra exposure services are
needed:

```bash
BAOTA_COMPOSE_PROFILES=frpc scripts/deployment/actions/render-baota-compose.sh
BAOTA_COMPOSE_PROFILES=cloudflare scripts/deployment/actions/render-baota-compose.sh
BAOTA_COMPOSE_PROFILES=cloudflare-quick scripts/deployment/actions/render-baota-compose.sh
```

Do not publish the internal HTTP origin `8080` to the host. Cloudflare Tunnel
uses `http://gateway-nginx:8080` only inside Docker.

## Updating

After changing `.env`, rerun the renderer and let Baota reload the generated
Compose file. Runtime data remains under ignored project paths such as
`data/home`, `data/wechat`, `data/qq`, and `data/authelia`.
