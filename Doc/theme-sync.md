# Theme Sync

Theme sync maps the browser `prefers-color-scheme` setting into KDE color
schemes.

At container startup, `custom-cont-init.d/65-theme-sync.sh` installs:

- `/usr/local/bin/kde-webtop-theme-sync`
- `codex-theme-sync.js` into the Selkies web roots

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
```

## Environment

- `ENABLE_THEME_SYNC`: set to `false` to skip script installation.
- `THEME_SYNC_LIGHT_SCHEME`: default `BreezeLight`.
- `THEME_SYNC_DARK_SCHEME`: default `BreezeDark`.
- `THEME_SYNC_LIGHT_LOOK_AND_FEEL`: default `org.kde.breeze.desktop`.
- `THEME_SYNC_DARK_LOOK_AND_FEEL`: default `org.kde.breezedark.desktop`.
- `SELKIES_COMMAND_ENABLED`: must remain `true` for browser-driven sync.

If KDE commands are missing, the script exits successfully after applying the
available config writes.
