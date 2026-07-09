# HTTPS Gateway

The active gateway is split into two Docker services:

- `gateway-nginx`: public HTTPS browser entrypoint using NGINX `auth_request`.
- `authelia`: authentication portal and authorization endpoint.

The old Node/Better Auth PAM gateway is not part of the active Compose stack.

## Gateway Flow

1. Browser requests `/`.
2. NGINX calls `/internal/authelia/authz`.
3. Authelia returns an allow/deny decision.
4. NGINX redirects unauthenticated users to `/authelia/`.
5. Successful Authelia login sets the session cookie for the gateway host.
6. NGINX proxies authenticated traffic to `webtop-kde:3000`.

Authelia runtime config, users, local SQLite storage, and branding assets are
generated under ignored `data/authelia/` by:

```bash
AUTHELIA_BOOTSTRAP_PASSWORD='change-this' scripts/ensure-authelia-config.sh
```
