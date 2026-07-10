# Networking and Exposure

The safest default is local-only HTTPS on the Docker host. Remote access should
publish only the authenticated gateway, never raw Webtop ports.

## Exposure Methods

- `local`: local browser access on the host.
- LAN or Tailscale: bind the gateway to an address reachable from trusted
  private devices.
- `frpc`: connect to an existing frps server and expose the gateway TLS port.
- `cloudflare_named`: stable Cloudflare hostname through a named tunnel.
- `cloudflare_quick`: temporary Cloudflare URL for testing.
- Public IP with ACME: direct public host using `sslip.io` or a manual domain
  and Let's Encrypt.

## Decision Guide

- Use local-only for first boot and debugging.
- Use LAN or Tailscale when all clients are trusted private devices.
- Use frpc when you already operate an frps server and have a token.
- Use Cloudflare named tunnel when you want a stable domain without opening
  inbound ports.
- Use Cloudflare quick tunnel only for temporary testing.
- Use public ACME only when the machine has a public IP and public TCP port
  `80` can reach Certbot during validation.

## Internal HTTP Origin

Cloudflare Tunnel uses:

```env
CLOUDFLARED_ORIGIN_URL=http://gateway-nginx:8080
```

This listener exists for Docker-internal origin traffic and runs the same auth
gateway. Do not publish it to the host or internet.
