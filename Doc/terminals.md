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
- `HOST_SSH_KEY`: SSH private key path inside the container. Default:
  `/config/.ssh/kde-webtop-host-ed25519`.

Because `${HOST_HOME}` is a project-local `/config`, SSH client keys and known
hosts are stored inside the project-local desktop home. The host terminal still
connects back to the real host account over SSH.

Run this once on the Docker host to enable passwordless Host SSH Terminal
logins:

```bash
scripts/setup-host-ssh-key.sh
```

The script generates the key under `/config/.ssh`, appends the public key to the
selected host user's `~/.ssh/authorized_keys`, preloads `known_hosts`, and tests
public-key login with password authentication disabled.

## Visual Difference

The host terminal starts with a yellow `HOST SSH terminal` banner and then
executes interactive `bash` on the host, so the host user's `.bashrc` and shell
customizations such as oh-my-bash are loaded.

The Docker terminal starts with a cyan `DOCKER local terminal` banner and then
executes interactive `bash` inside the container.
