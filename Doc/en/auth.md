# Authentication

The browser entrypoint is `gateway-nginx`. It uses NGINX `auth_request` before
proxying traffic to Webtop.

## PAM Helper

The default provider is the project host-side PAM helper. The helper runs on
the Docker host and verifies the selected Linux account through PAM over a Unix
socket mounted into the gateway container.

Benefits:

- Browser login can follow the host account password.
- The container does not need `/etc/shadow`.
- Password changes on the host are reflected by PAM without regenerating an
  Authelia users file.

The installer can install and start the helper when run with sufficient
privileges. Manual helper details live in
[the PAM auth helper README](../../gateway/pam-auth/README.md).

## Authelia Fallback

Authelia remains available as an optional file-user auth provider. Its bootstrap
password is a one-time value hashed into `data/authelia/users_database.yml`.
That is not live PAM synchronization. Use PAM mode if you want host-password
login.

## Gateway Boundary

Raw Webtop ports stay inside Docker. Whether you use local HTTPS, frpc,
Cloudflare Tunnel, LAN/Tailscale, or public ACME, route users to the gateway,
not to Webtop directly.
