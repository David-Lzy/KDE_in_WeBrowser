# Install

Generate local deployment files:

```bash
scripts/install.sh --preset balanced
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

Useful options:

- `--preset low-bandwidth`
- `--preset balanced`
- `--preset quality`
- `--mount /host/path:/container/path[:ro]`
- `--with-wechat-qq`
- `--with-frpc`
- `--start`

The script checks Docker, Docker Compose, `/dev/dri`, and `nvidia-smi`.
