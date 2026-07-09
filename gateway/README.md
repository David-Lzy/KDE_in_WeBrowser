# PAM Auth Gateway

The gateway is split into two Docker services:

- `gateway-nginx`: public browser entrypoint using NGINX `auth_request`.
- `gateway-app`: Node/Express app with Better Auth mounted at `/api/auth/*`,
  login UI, session cookie validation, cooldown tracking, and a PAM helper
  client.

The host PAM verifier runs outside Docker because PAM must execute on the host.

## Host Helper

Install the helper on the Docker host:

```bash
sudo gateway/host/install-pam-helper.sh
```

The installer compiles a small PAM checker and starts
`kde-webtop-pam-helper.service`, which listens on:

```text
/run/kde-webtop-pam/helper.sock
```

The Docker gateway mounts `/run/kde-webtop-pam` and sends one JSON request per
login attempt.

## Gateway Flow

1. Browser requests `/`.
2. NGINX calls `/auth_request`.
3. `gateway-app` returns `204` for a valid session or `401` for no session.
4. NGINX redirects unauthenticated users to `/auth/login`.
5. Login POST verifies the selected host user's password through the host PAM
   helper.
6. Successful login sets an HTTP-only gateway session cookie.

Better Auth is mounted for the auth service boundary and future plugin work.
The PAM flow currently uses a minimal gateway session cookie so the NGINX
`auth_request` path has a small, deterministic verifier.
