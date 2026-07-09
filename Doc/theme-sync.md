# Theme Sync

Theme sync maps Selkies client state into KDE session preferences:

- browser `prefers-color-scheme` to KDE Breeze light/dark
- browser device pixel ratio to Selkies DPI and KDE scale state
- host user language to KDE locale and the Selkies HTML `lang` attribute

At container startup, `custom-cont-init.d/65-theme-sync.sh` installs:

- `/usr/local/bin/kde-webtop-theme-sync`
- `codex-theme-sync.js` into the Selkies web roots

`custom-cont-init.d/55-kde-session-prefs.sh` also writes
`/config/.config/plasma-localerc` from `WEBTOP_LANG`, `WEBTOP_LANGUAGE`, and
`WEBTOP_LC_ALL`. `scripts/detect-host-user.sh` prefers the host user's
`~/.config/plasma-localerc` and `~/.pam_environment` before falling back to the
system locale.

`custom-cont-init.d/60-auto-hidpi-dpi.sh` sends both Selkies `scaling_dpi` and
`/usr/local/bin/kde-webtop-scale-sync <dpi>` so KDE records the same scale that
Selkies uses for the stream.

The browser script observes `prefers-color-scheme` and sends a Selkies command
message that runs:

```bash
/usr/local/bin/kde-webtop-theme-sync dark
/usr/local/bin/kde-webtop-theme-sync light
```

Manual fallback inside the container:

```bash
kde-webtop-theme-sync dark
kde-webtop-theme-sync light
kde-webtop-theme-sync toggle
kde-webtop-theme-sync status
kde-webtop-scale-sync 144
kde-webtop-session-sync
kde-webtop-session-sync --restart-plasma
```

Host-side reload without recreating the Docker container:

```bash
scripts/reload-kde-session.sh
scripts/reload-kde-session.sh --restart-plasma
```

The host-side script reads the current `.env` and passes the relevant language,
theme, and container-user values into `docker exec`, so `.env` edits can be
applied without recreating the container.

Theme and DPI changes are hot-applied through Selkies command messages. Locale
config and Selkies HTML language can also be rewritten live, but already
running application processes keep the environment they started with. Use
`--restart-plasma` after changing language if the Plasma shell itself must be
refreshed without recreating the container. Recreating `webtop-kde` remains the
cleanest way to guarantee every process inherits a new locale.

## Environment

- `ENABLE_THEME_SYNC`: set to `false` to skip script installation.
- `ENABLE_KDE_SESSION_PREFS`: set to `false` to skip KDE locale/session writes.
- `WEBTOP_LANG`: KDE process locale, for example `zh_CN.UTF-8`.
- `WEBTOP_LANGUAGE`: KDE translation language, for example `zh_CN`.
- `WEBTOP_LC_ALL`: full locale override used by the container.
- `THEME_SYNC_LIGHT_SCHEME`: default `BreezeLight`.
- `THEME_SYNC_DARK_SCHEME`: default `BreezeDark`.
- `THEME_SYNC_LIGHT_LOOK_AND_FEEL`: default `org.kde.breeze.desktop`.
- `THEME_SYNC_DARK_LOOK_AND_FEEL`: default `org.kde.breezedark.desktop`.
- `SELKIES_COMMAND_ENABLED`: must remain `true` for browser-driven sync.

If KDE commands are missing, the script exits successfully after applying the
available config writes.
