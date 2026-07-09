# HTTPS Gateway

The active gateway is split into two Docker services:

- `gateway-nginx`: public HTTPS browser entrypoint using NGINX `auth_request`.
- `authelia`: optional authentication portal and authorization endpoint.
- host PAM auth helper: default live host-password authentication service.

## Gateway Flow

1. Browser requests `/`.
2. NGINX calls the configured internal auth endpoint.
3. With the default PAM provider, the host-side helper checks the session
   cookie or redirects unauthenticated users to `/auth/login`.
4. Login posts are validated against the host PAM stack.
5. The helper sets the session cookie for the gateway host.
6. NGINX proxies authenticated traffic to `webtop-kde:3000`.

Install the host-side PAM helper after cloning:

```bash
scripts/install-pam-auth-helper.sh
```

The helper runs on the host as a systemd service and exposes only a Unix socket
mounted into `gateway-nginx`. It does not require mounting host password files
into Docker.

Authelia runtime config, users, local SQLite storage, and branding assets are
generated under ignored `data/authelia/` by:

```bash
AUTHELIA_BOOTSTRAP_PASSWORD='change-this' scripts/ensure-authelia-config.sh
```

Use the selected host account password as `AUTHELIA_BOOTSTRAP_PASSWORD` if the
browser login should match the host account. This does not enable live PAM
authentication; the helper hashes that value into Authelia's file user database.
If `.env` still contains a legacy `PASSWORD` and `AUTHELIA_BOOTSTRAP_PASSWORD`
is omitted during first generation, the helper uses `PASSWORD` as a fallback.

The Authelia backend is still `file`, not PAM. Use it as an optional fallback by
setting `GATEWAY_AUTH_PROVIDER=authelia` and
`GATEWAY_AUTH_INTERNAL_URI=/internal/authelia/authz`.
