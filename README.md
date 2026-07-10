# KDE in Web Browser

[中文说明](README.zh-CN.md) | [English docs](Doc/en/index.md) | [中文文档](Doc/zh-CN/index.md)

KDE in Web Browser gives you a persistent KDE Plasma desktop in Docker, streamed
through a browser with Selkies and protected by an authenticated HTTPS gateway.
It is designed for people who want one always-on Linux desktop for WeChat, QQ,
clipboard sync, host terminals, remote GUI workflows, and browser-based access
from Windows, macOS, Linux, tablets, or thin clients.

## What It Is Good For

- **One WeChat/QQ desktop from every device**: keep WeChat, QQ, received files,
  desktop settings, and app state in one server-side Linux desktop instead of
  spreading them across several local desktop clients.
- **Less chat-history fragmentation**: this project does not merge unrelated
  WeChat histories, but it helps you stop creating new desktop-side history
  islands by always using the same remote desktop profile.
- **Plain-file data migration**: WeChat/QQ profile and file directories are
  host-mounted folders. You can back them up or move them with normal tools
  such as `scp` and `rsync`.
- **Clipboard and input workflow**: browser clipboard support, Selkies
  clipboard settings, and a Wayland/Xwayland text clipboard bridge make copy
  and paste usable between the browser, KDE apps, WeChat, and QQ. Input method
  settings live in the persistent KDE desktop instead of being rebuilt on every
  client machine.
- **Remote GUI for minimal Linux**: add a browser-accessible KDE desktop to a
  headless server, minimal cloud VM, lab machine, or personal workstation
  without installing a full remote desktop client on every device.
- **WSL-friendly concept**: when Docker and networking are available, the same
  stack can serve as a browser-based Linux desktop workflow for WSL/WSL2-style
  environments. GPU, systemd, and host integration depend on the local WSL
  setup.
- **Multiple exposure paths**: use local-only, LAN/Tailscale, frpc, Cloudflare
  named tunnel, Cloudflare quick tunnel, or public-IP HTTPS with ACME.

## Highlights

- KDE Plasma Wayland desktop based on LinuxServer Webtop.
- Selkies browser streaming with clipboard, DPI, and resize support.
- Optional WeChat and QQ image layer based on the existing `wechat-selkies`
  application assets.
- Host-side PAM authentication by default, with optional Authelia fallback.
- HTTPS gateway in front of Webtop; raw Webtop ports stay inside Docker.
- Project-local desktop home mounted as `/config` so runtime state stays out of
  the Git repository.
- Host SSH and Docker terminal shortcuts inside KDE.
- Theme, locale, and DPI synchronization from browser/user settings into KDE.
- Baota/BT Panel rendering for a single Compose file plus a complete env file.
- Interactive bilingual deployment wizard with defaults and optional exposure
  setup.

## Quick Start

Requirements:

- Linux host with Docker and the Docker Compose plugin.
- Enough disk space for a KDE/Webtop image and a persistent desktop home.
- `sudo` or root access if you want the default host PAM auth helper.

Recommended interactive setup:

```bash
scripts/deployment/configure.sh
```

The wizard asks for a language first. Press Enter to accept recommended values.
For sensitive values such as frpc tokens, Cloudflare API tokens, or Authelia
bootstrap passwords, enter a value or type `skip` explicitly.

Unattended local-only setup with defaults:

```bash
sudo scripts/deployment/configure.sh --language en --defaults --force --start
```

`--defaults` is intentionally conservative: frpc, Cloudflare Tunnel, and public
ACME are not enabled because the script cannot guess your tokens, domain, or
public-network intent.

After startup, open the gateway URL from `.env`. The default local URL is:

```text
https://127.0.0.1:18080
```

## Architecture

```text
Browser
  |
  | HTTPS, frpc, Cloudflare Tunnel, LAN, or Tailscale
  v
gateway-nginx  -- auth_request -->  PAM helper or Authelia
  |
  | Docker network only
  v
kde-webtop  -- Selkies --> KDE Plasma Wayland
  |
  +-- WeChat / QQ
  +-- Host SSH terminal shortcut
  +-- Clipboard, theme, locale, and DPI sync scripts
```

Raw Webtop ports are not published by default. Public or remote access should go
through the authenticated gateway.

## WeChat/QQ Data

Personal account data is not baked into the image. Important paths are
configured in `.env`:

```env
WECHAT_PROFILE_DIR=/path/to/data/wechat/.xwechat
WECHAT_FILES_DIR=/path/to/data/wechat/xwechat_files
QQ_DATA_DIR="/path/to/data/qq/Tencent Files"
```

To move existing data, stop the stack first, then copy files into those mapped
host directories:

```bash
docker compose --env-file .env -f compose/webtop-kde.yml down

rsync -aH --info=progress2 old-host:/old/path/.xwechat/ \
  /path/to/KDE_in_WeBrowser/data/wechat/.xwechat/

rsync -aH --info=progress2 old-host:/old/path/xwechat_files/ \
  /path/to/KDE_in_WeBrowser/data/wechat/xwechat_files/
```

For smaller moves, `scp -r` is also fine. Back up the destination before
overwriting existing profile data.

## Documentation

Start here:

- [English documentation index](Doc/en/index.md)
- [中文文档索引](Doc/zh-CN/index.md)

Common topics:

- [Install and deployment](Doc/en/install.md)
- [Configuration model](Doc/en/configuration.md)
- [WeChat/QQ and chat data](Doc/en/wechat-qq.md)
- [Clipboard and input workflow](Doc/en/clipboard-input.md)
- [Remote GUI scenarios](Doc/en/remote-gui.md)
- [Networking and exposure choices](Doc/en/networking.md)
- [Authentication](Doc/en/auth.md)
- [Cloudflare Tunnel](Doc/en/cloudflare-tunnel.md)
- [Public DNS and ACME](Doc/en/public-acme.md)
- [Validation](Doc/en/validation.md)

## Repository Boundaries

This repository should contain reusable code, templates, scripts, and public
documentation only. Do not commit:

- `.env`, `compose.local.yml`, or generated Baota env files
- WeChat/QQ profile or chat data
- frpc tokens, Cloudflare tokens, or tunnel tokens
- TLS private keys
- runtime desktop homes, caches, logs, or imported personal artifacts
- private agent notes under `.agent/` or `.local/`
