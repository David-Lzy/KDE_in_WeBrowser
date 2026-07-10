# frpc Exposure

frpc is optional and disabled by default.

When network detection reports `private_or_nat`, including LAN-only, CGNAT, and
Tailscale-only hosts, the deployment wizard lets you choose local-only, frpc,
Cloudflare named tunnel, or Cloudflare quick tunnel. If you prefer Cloudflare,
see [Cloudflare Tunnel](cloudflare-tunnel.md). If the host has a public IPv4
and public TCP port `80`, see [Public DNS and ACME](public-acme.md) instead.

Enable it by copying the sanitized example and using the `frpc` profile:

```bash
cp modules/frpc/frpc.example.toml modules/frpc/frpc.toml
$EDITOR modules/frpc/frpc.toml
docker compose --env-file .env -f compose/webtop-kde.yml --profile frpc up -d
```

The interactive deployment wizard can generate the private frpc file instead:

```bash
scripts/deployment/configure.sh
```

When frpc is enabled, the wizard asks for the frps address and token. Enter is
not accepted for those fields; type a value or the literal `skip`. If a custom
frpc config path is selected, the wizard writes `FRPC_CONFIG_FILE` into `.env`
so the Compose template mounts that exact file.

Only expose the authenticated gateway:

```text
localIP = "gateway-nginx"
localPort = 8443
```

Port `8443` is the gateway NGINX TLS listener. Do not expose raw Webtop ports
`3000` or `3001` through frpc.

`modules/frpc/frpc.toml` is ignored because it contains the real frps host,
remote port, and token.
