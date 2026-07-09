# Host User Mode

The default deployment mode authenticates one selected host user, but maps a
project-local desktop home into the container as `/config`.

Generate a local `.env` file:

```bash
scripts/detect-host-user.sh "$USER" > .env
$EDITOR .env
```

Important fields:

- `HOST_USER`: selected host account.
- `HOST_UID`: numeric UID used for LinuxServer `PUID`.
- `HOST_GID`: numeric GID used for LinuxServer `PGID`.
- `HOST_HOME`: project-local host path mounted as `/config`.
- `CONTAINER_USER`: compatibility account added inside the container, normally
  `docker_${HOST_USER}`.

LinuxServer Webtop still keeps its internal `abc` account. The project adds
`CONTAINER_USER` as the preferred passwd/group entry for the same UID/GID and
`/config` home, so UID lookups display `docker_${HOST_USER}` while
LinuxServer services that call `s6-setuidgid abc` keep working.

## Warning

Desktop-home mode writes KDE and application state into `${HOST_HOME}`. The
installer sets this under the ignored project `data/` directory so the container
does not write into your primary host home by default.
