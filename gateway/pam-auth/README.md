# PAM Auth Helper

This helper provides live host PAM authentication for the HTTPS gateway.

The helper runs on the Docker host as root through systemd, listens on a Unix
socket under the project data directory, and validates login attempts with the
host PAM stack. `gateway-nginx` mounts only that socket and uses `auth_request`
against the helper. The container does not receive `/etc/shadow` or the host PAM
module tree.

Install or refresh the host-side service:

```bash
scripts/deployment/actions/install-pam-auth-helper.sh
```

The installer creates:

- `/etc/pam.d/kde-webtop`, using `common-auth` and `common-account` when
  available.
- `/etc/systemd/system/kde-webtop-pam-auth.service`
- project-local runtime files under `data/pam-auth/`

Relevant `.env` keys:

- `GATEWAY_AUTH_PROVIDER=pam`
- `GATEWAY_AUTH_INTERNAL_URI=/internal/pam/authz`
- `PAM_AUTH_RUN_DIR`
- `PAM_AUTH_STATE_DIR`
- `PAM_AUTH_SOCKET_CONTAINER`
- `PAM_AUTH_SERVICE`
- `PAM_AUTH_ALLOWED_USERS`
- `PAM_AUTH_SESSION_TTL_SECONDS`
- `PAM_AUTH_COOKIE_NAME`

By default only the selected `HOST_USER` is allowed to log in.

To use Authelia instead, set:

```env
GATEWAY_AUTH_PROVIDER=authelia
GATEWAY_AUTH_INTERNAL_URI=/internal/authelia/authz
```
