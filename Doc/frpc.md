# frpc Exposure

frpc is optional and disabled by default.

Enable it by copying the sanitized example and using the `frpc` profile:

```bash
cp modules/frpc/frpc.example.toml modules/frpc/frpc.toml
$EDITOR modules/frpc/frpc.toml
docker compose --env-file .env -f compose/webtop-kde.yml --profile frpc up -d
```

Only expose the authenticated gateway:

```text
localIP = "gateway-nginx"
localPort = 8080
```

Do not expose raw Webtop ports `3000` or `3001` through frpc.

`modules/frpc/frpc.toml` is ignored because it contains the real frps host,
remote port, and token.
