# Cloudflare Tunnel

Cloudflare Tunnel is an optional exposure path for hosts behind NAT, CGNAT,
LAN-only networks, or Tailscale-only access.

The deployment wizard supports two modes:

- `cloudflare_named`: stable hostname, created and configured through the
  Cloudflare API.
- `cloudflare_quick`: temporary public URL from `cloudflared tunnel --url`.

Named tunnel is recommended for normal use. Quick tunnel is useful for a short
test because the generated URL is not stable.

## Named tunnel

Run the wizard:

```bash
scripts/configure-deployment.sh
```

When network detection reports `private_or_nat`, choose:

```text
cloudflare_named
```

The wizard asks for:

- Cloudflare API token
- Account ID
- Zone ID
- public hostname, such as `kde.example.com`
- tunnel name

The API token must be active and authorized for the selected account and zone.
Recommended permissions:

- Account: Cloudflare Tunnel or Connector write access
- Zone: DNS write access

The wizard validates the token before writing the final local config. If the
check fails, enter a corrected token or type `skip`.

After validation, `scripts/setup-cloudflare-tunnel.sh` creates or reuses the
named tunnel, writes the ingress rule, creates or updates the DNS CNAME, gets
the tunnel run token, and writes it to `.env`.

The Compose profile is:

```bash
docker compose --env-file .env -f compose/webtop-kde.yml --profile cloudflare up -d
```

## Quick tunnel

Choose:

```text
cloudflare_quick
```

The Compose profile runs:

```bash
cloudflared tunnel --url http://gateway-nginx:8080
```

Use this only for temporary testing. It does not require a Cloudflare API token
and does not create a stable hostname.

## Origin URL

The default origin is:

```env
CLOUDFLARED_ORIGIN_URL=http://gateway-nginx:8080
```

This address is inside the Docker network. It is not published to the host or
the public Internet. The public host still connects over HTTPS at the
Cloudflare edge, and NGINX still enforces the configured PAM or Authelia
authentication before proxying to Webtop.

Do not publish gateway port `8080` in Compose. The host-facing listener remains
the HTTPS gateway on `8443`, mapped by `GATEWAY_PORT`.

## Local files

Cloudflare secrets stay in ignored local files:

- `.env`
- generated Baota env files

Do not commit real values for:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARED_TUNNEL_TOKEN`

## References

- [Cloudflare Tunnel setup](https://developers.cloudflare.com/tunnel/setup/)
- [Create tunnel with the API](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/)
- [Create and verify API tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [Tunnel origin parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/)
