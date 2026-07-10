# Public DNS and ACME

The deployment wizard detects whether the host looks public or private/NAT.

- `private_or_nat`: the wizard recommends frpc because Let's Encrypt HTTP-01
  cannot validate a service that the public internet cannot reach directly.
- `public_direct`: the wizard can configure a public hostname and automatic
  Let's Encrypt certificates.

## Public Direct Mode

The recommended no-account domain option is `sslip.io`. For a public IPv4 such
as `203.0.113.10`, the wizard proposes a hostname like:

```text
kde-203-0-113-10.sslip.io
```

That hostname resolves to the embedded public IP. You can also choose `manual`
and enter your own domain if its A record already points to this host.

Let's Encrypt HTTP-01 requires public TCP port `80`. In ACME mode the wizard
sets:

```env
GATEWAY_BIND=0.0.0.0
GATEWAY_PORT=443
GATEWAY_PUBLIC_BASE_URL=https://your-domain
ACME_ENABLED=true
ACME_HTTP_PORT=80
```

Docker still publishes only the authenticated HTTPS gateway. Certbot standalone
opens TCP port `80` temporarily during certificate issuance and renewal for the
HTTP-01 challenge, then closes it.

## Renewal

`scripts/setup-public-acme.sh` uses Certbot standalone HTTP-01 mode. It
requests the certificate, copies the issued `fullchain.pem` and `privkey.pem`
into the gateway TLS paths, and reloads `gateway-nginx`.

When `ACME_AUTO_RENEW=true`, the script installs:

```text
/etc/systemd/system/kde-webtop-acme-renew.service
/etc/systemd/system/kde-webtop-acme-renew.timer
/etc/letsencrypt/renewal-hooks/deploy/kde-webtop-*.sh
```

The renewal hook calls `scripts/deploy-acme-cert.sh`, so renewed certificates
are copied back into the project `ssl/` directory and NGINX is reloaded.

## Manual Commands

After `.env` is ready and the stack is running:

```bash
sudo scripts/setup-public-acme.sh --env-file .env
```

To redeploy an already issued certificate:

```bash
sudo scripts/deploy-acme-cert.sh --env-file .env
```

For NAT, CGNAT, Tailscale-only, or LAN-only hosts, use frpc instead.

## References

- [Let's Encrypt challenge types](https://letsencrypt.org/docs/challenge-types/)
- [Certbot standalone and renewal documentation](https://eff-certbot.readthedocs.io/en/stable/using.html)
- [sslip.io wildcard DNS service](https://sslip.io/)
