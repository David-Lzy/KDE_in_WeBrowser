# Documentation Index

[Back to README](../../README.md) | [中文文档](../zh-CN/index.md)

## Install and Deployment

- [Install](install.md): wizard, unattended defaults, local files, and start
  commands.
- [Configuration](configuration.md): `.env`, `compose.local.yml`, profiles, and
  generated local state.
- [Baota/BT Panel](baota.md): render a panel-friendly Compose file and env file.
- [Host User Mode](host-user.md): map a host account into a project-local
  desktop home.

## Usage Scenarios

- [WeChat/QQ](wechat-qq.md): image layer, data mapping, chat data migration.
- [Remote GUI](remote-gui.md): headless/minimal Linux, servers, lab machines,
  and WSL-style workflows.
- [Clipboard and Input](clipboard-input.md): browser clipboard, Selkies, and
  Wayland/Xwayland text clipboard bridging.

## Remote Access

- [Networking](networking.md): local, LAN, Tailscale, NAT, public IP, and
  exposure decision guide.
- [frpc](frpc.md): publish the authenticated HTTPS gateway through frps.
- [Cloudflare Tunnel](cloudflare-tunnel.md): named tunnel and quick tunnel.
- [Public DNS and ACME](public-acme.md): public IP, sslip.io/manual domain, and
  Let's Encrypt.

## Technical Details

- [Architecture](architecture.md): components and runtime boundaries.
- [Authentication](auth.md): PAM helper, Authelia fallback, and gateway model.
- [Terminal Integration](terminals.md): host SSH and Docker terminal shortcuts.
- [Theme, Locale, and DPI](theme-locale-dpi.md): browser/client state mapped
  into KDE.
- [Bandwidth](bandwidth.md): Selkies quality presets and variables.
- [Validation](validation.md): automated checks and manual browser checklist.

## Adjacent References

- [Compose templates](../../compose/README.md)
- [Gateway details](../../gateway/README.md)
- [PAM auth helper](../../gateway/pam-auth/README.md)
