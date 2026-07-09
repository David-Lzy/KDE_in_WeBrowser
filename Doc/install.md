# Install

Recommended interactive setup:

```bash
scripts/configure-deployment.sh
```

The wizard:

- asks for Chinese or English prompts first.
- uses the value shown in parentheses when Enter is pressed.
- requires an explicit value or the literal `skip` for sensitive required
  values such as frpc token, frps address, Authelia bootstrap password, and bind
  mount specs.
- writes a customized `.env` and `compose.local.yml`.
- can optionally write `modules/frpc/frpc.toml`, generate local TLS, generate
  Authelia config, set up the host SSH key, validate Compose, and start the
  stack.

Useful wizard options:

- `--language zh|en`
- `--defaults`
- `--no-actions`
- `--force`
- `--start`
- `--env-file PATH`
- `--compose-file PATH`
- `--frpc-file PATH`

Example dry run into temporary files:

```bash
tmpdir="$(mktemp -d)"
scripts/configure-deployment.sh \
  --language en \
  --defaults \
  --force \
  --no-actions \
  --env-file "${tmpdir}/.env" \
  --compose-file "${tmpdir}/compose.local.yml"
docker compose --env-file "${tmpdir}/.env" \
  -f compose/webtop-kde.yml \
  -f "${tmpdir}/compose.local.yml" \
  config --quiet
```

The older non-interactive installer is still available for simple local
deployments:

```bash
scripts/install.sh --preset balanced
```

Generate the private Authelia config before the first start:

```bash
AUTHELIA_BOOTSTRAP_PASSWORD='change-this' scripts/ensure-authelia-config.sh
```

The installer writes:

- `.env`
- `compose.local.yml`

It backs up existing local deployment files under `backups/<timestamp>/` before
overwriting, and it asks before replacing existing files unless `--force` is
provided.

Start the stack:

```bash
docker compose --env-file .env -f compose/webtop-kde.yml -f compose.local.yml up -d
```

Open the gateway URL from `.env`, normally:

```text
https://127.0.0.1:18080
```

The gateway uses Authelia for browser authentication. Raw Webtop ports are not
published by default.

Useful options:

- `--preset low-bandwidth`
- `--preset balanced`
- `--preset quality`
- `--mount /host/path:/container/path[:ro]`
- `--with-wechat-qq`
- `--with-frpc`
- `--start`

The script checks Docker, Docker Compose, `/dev/dri`, and `nvidia-smi`.
