# Terminal Integration

The KDE desktop creates two terminal entry points at container startup:

- `Host SSH Terminal`: Konsole profile that SSHes to the selected host user.
- `Docker Terminal`: Konsole profile that opens a local shell inside the
  desktop container.

The host terminal defaults to:

```text
${HOST_USER}@host.docker.internal:${HOST_SSH_PORT}
```

On Linux Docker, Compose maps `host.docker.internal` to the Docker host through
`host-gateway`.

## Environment

- `ENABLE_TERMINAL_INTEGRATION`: set to `false` to skip all terminal setup.
- `HOST_SSH_HOST`: host name or IP for the host terminal.
- `HOST_SSH_PORT`: SSH port. `scripts/detect-host-user.sh` reads
  `ssh.socket` when available; Compose falls back to `22` if the variable is
  unset.
- `HOST_SSH_TARGET`: optional full SSH target. If empty, the container uses
  `${HOST_USER}@${HOST_SSH_HOST}`.

Because `${HOST_HOME}` is mounted as `/config`, the SSH client can use the
selected host user's existing `/config/.ssh` keys and known hosts.

## Visual Difference

The host terminal starts with a yellow `HOST SSH terminal` banner and uses a
`[HOST user@host cwd]` prompt.

The Docker terminal starts with a cyan `DOCKER local terminal` banner and uses a
`[DOCKER user@container cwd]` prompt.
