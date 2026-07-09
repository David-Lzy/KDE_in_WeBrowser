# KDE in Web Browser

A personal KDE Plasma desktop that runs in Docker and opens from a browser.
It is built for people who want one persistent Linux desktop for WeChat, QQ,
host terminals, clipboard sync, and remote access without installing a full
desktop client on every device.

<details>
<summary>中文说明</summary>

这是一个运行在 Docker 里的个人 KDE Plasma 桌面，可以直接用浏览器访问。
它适合把微信、QQ、宿主机终端、剪贴板同步和远程访问集中到一个长期运行的
Linux 桌面里，而不是在每台 Windows/macOS/Linux 机器上分别安装桌面客户端。

</details>

## Why This Project

- **One persistent desktop**: KDE, WeChat, QQ, browser-facing Selkies, and
  helper scripts share one `/config` home mounted from the host.
- **Windows/browser clipboard bridge**: browser clipboard support, Selkies
  clipboard settings, and the Wayland/Xwayland bridge keep text clipboard
  content moving between the Windows browser, KDE apps, WeChat, and QQ.
- **Less WeChat history fragmentation**: use the same remote desktop from every
  device instead of logging into multiple desktop clients with separate local
  data stores. This does not merge histories automatically; it avoids creating
  more desktop-side history silos.
- **Data is plain files on the host**: WeChat profile data, received files, QQ
  data, TLS files, frpc config, and PAM state live under ignored host paths, so
  they can be backed up or migrated with normal tools such as `scp` and `rsync`.
- **Host-account login**: the default gateway uses a host-side PAM helper, so
  browser login can follow the selected Linux account password without copying
  `/etc/shadow` into containers.
- **HTTPS-only public entrypoint**: raw Webtop ports stay inside Docker; the
  host publishes the authenticated HTTPS gateway.
- **Panel-friendly deployment**: Baota/BT Panel can use a generated single
  Compose file plus a full env file, while normal users keep editing `.env`.

<details>
<summary>中文：项目优势</summary>

- **一个持久化桌面**：KDE、微信、QQ、Selkies 和脚本共享同一个宿主机挂载的
  `/config`。
- **Windows/浏览器剪贴板同步**：通过浏览器剪贴板、Selkies 剪贴板能力和
  Wayland/Xwayland 文本剪贴板桥，在 Windows 浏览器、KDE、微信、QQ 之间同步
  文本剪贴板。
- **减少微信聊天记录割裂**：所有设备都远程进入同一个桌面，不再在多个桌面端
  客户端之间反复登录并产生不同的本地数据。它不会自动合并历史记录，但能避免
  后续继续制造新的桌面端记录孤岛。
- **数据就是宿主机文件**：微信 profile、聊天文件、QQ 数据、TLS、frpc、PAM
  状态都落在 ignored 的宿主机目录，可用 `scp`/`rsync` 备份或迁移。
- **宿主账号登录**：默认网关用宿主 PAM helper 认证，浏览器登录可以跟随选定
  Linux 账号密码，不把 `/etc/shadow` 放进容器。
- **公网只暴露 HTTPS 网关**：Webtop 原始端口留在 Docker 网络里，对外只暴露
  认证后的 HTTPS 入口。
- **适配宝塔面板**：可以生成单个 Compose 文件和完整 env 文件；普通配置只改
  `.env`。

</details>

## Architecture

```text
Browser
  |
  | HTTPS
  v
gateway-nginx  -- auth_request -->  PAM helper or Authelia
  |
  | Docker network
  v
kde-webtop  -- Selkies --> KDE Plasma Wayland
  |
  +-- WeChat / QQ
  +-- Host SSH terminal shortcut
  +-- Clipboard, theme, locale, and DPI sync scripts
```

Main components:

- `compose/webtop-kde.yml`: Docker Compose template.
- `custom-cont-init.d/`: KDE/Selkies init hooks for locale, theme, HiDPI,
  clipboard, terminal shortcuts, and WeChat/QQ desktop entries.
- `gateway/nginx/`: HTTPS reverse proxy and `auth_request` gateway.
- `gateway/pam-auth/`: host-side PAM auth helper.
- `modules/wechat-qq/`: WeChat/QQ image layer and launcher assets.
- `scripts/`: installer, deployment wizard, Baota renderer, validation, TLS,
  PAM helper, SSH key, and maintenance scripts.
- `Doc/`: focused documentation for install, architecture, frpc, terminals,
  theme sync, validation, and WeChat/QQ data.

## Quick Start

Recommended interactive setup:

```bash
scripts/configure-deployment.sh
```

The wizard asks for Chinese or English prompts first. Press Enter to use the
recommended value. For sensitive required values such as frpc token or Authelia
bootstrap password, enter a value or type `skip` explicitly.

Unattended local setup with recommended defaults:

```bash
scripts/configure-deployment.sh --language en --defaults --force --start
```

This still requires Docker, Docker Compose, and root/passwordless sudo for the
host PAM helper. Secrets such as frpc tokens are intentionally skipped unless
you provide them interactively or edit `.env` and `modules/frpc/frpc.toml`.

Fast local setup:

```bash
scripts/install.sh --preset balanced
docker compose --env-file .env -f compose/webtop-kde.yml up -d
```

Open the gateway URL from `.env`, normally:

```text
https://127.0.0.1:18080
```

For Baota/BT Panel:

```bash
scripts/render-baota-compose.sh
docker compose --env-file data/baota/.env -f data/baota/docker-compose.yml up -d
```

Use `data/baota/docker-compose.yml` as the Compose file and `data/baota/.env`
as the env file in Baota.

## Configuration Model

Most deployment settings live in `.env`:

- ports and bind address
- host user, container display user, and hostname
- language, timezone, theme sync, and DPI sync
- Selkies bandwidth/quality settings
- WeChat/QQ install and autostart toggles
- WeChat/QQ data paths
- PAM helper and optional Authelia settings
- frpc config path

`compose.local.yml` is optional and only needed for structural overrides such
as extra bind mounts. Baota users should edit `data/baota/.env`; it contains
the same settings with absolute paths.

## Clipboard Sync

Enablement is controlled by:

```env
SELKIES_CLIPBOARD_ENABLED=true
SELKIES_CLIPBOARD_IN_ENABLED=true
SELKIES_CLIPBOARD_OUT_ENABLED=true
SELKIES_ENABLE_BINARY_CLIPBOARD=true
ENABLE_XWAYLAND_CLIPBOARD_BRIDGE=true
```

What this gives you:

- copy text on Windows, paste in the browser desktop;
- copy text in KDE/WeChat/QQ, paste back on Windows;
- bridge text between native Wayland apps and Xwayland apps such as WeChat/QQ;
- keep the desktop usable from browsers without installing a native remote
  desktop client.

Browser clipboard permissions still matter. If paste/copy does not work, check
the browser permission prompt and the Selkies clipboard panel.

<details>
<summary>中文：剪贴板同步</summary>

默认配置会打开 Selkies 剪贴板能力和 Wayland/Xwayland 文本剪贴板桥。实际效果是：

- Windows 里复制文本，可以粘贴进浏览器里的 KDE/微信/QQ；
- KDE/微信/QQ 里复制文本，可以粘贴回 Windows；
- Wayland 原生应用和 Xwayland 应用之间也能同步文本剪贴板。

如果不可用，优先检查浏览器是否允许页面读写剪贴板，以及 Selkies 侧边栏里的
clipboard 设置。

</details>

## WeChat/QQ Data and Chat History

The container does not bake in personal account data. The important host paths
are:

```env
WECHAT_PROFILE_DIR=/path/to/data/wechat/.xwechat
WECHAT_FILES_DIR=/path/to/data/wechat/xwechat_files
QQ_DATA_DIR="/path/to/data/qq/Tencent Files"
```

Why this helps with WeChat:

- Many desktop chat clients keep local history per client installation and per
  local profile path.
- If you log into different desktop clients on different machines, history and
  files may appear inconsistent.
- This project keeps one persistent desktop-side WeChat profile, then lets all
  your machines access that same desktop through the browser.

To migrate existing data, stop the stack first:

```bash
docker compose --env-file .env -f compose/webtop-kde.yml down
```

Then copy the old data into the mapped host directories. Prefer `rsync` when
you can preserve metadata:

```bash
rsync -aH --info=progress2 old-host:/old/path/.xwechat/ \
  /path/to/KDE_in_WeBrowser/data/wechat/.xwechat/

rsync -aH --info=progress2 old-host:/old/path/xwechat_files/ \
  /path/to/KDE_in_WeBrowser/data/wechat/xwechat_files/
```

Simple `scp` also works for many cases:

```bash
scp -r old-host:/old/path/.xwechat \
  /path/to/KDE_in_WeBrowser/data/wechat/

scp -r old-host:/old/path/xwechat_files \
  /path/to/KDE_in_WeBrowser/data/wechat/
```

Back up the destination before overwriting existing profile data. Do not commit
these directories; they contain private account data and chat files.

<details>
<summary>中文：微信聊天记录和 scp 迁移</summary>

这个项目不会把个人微信/QQ数据打进镜像。微信相关数据通过宿主机目录挂载：

```env
WECHAT_PROFILE_DIR=/path/to/data/wechat/.xwechat
WECHAT_FILES_DIR=/path/to/data/wechat/xwechat_files
```

这样做的意义是：微信桌面端通常会把聊天记录和文件放在当前客户端/当前 profile
路径下。如果你在多台电脑上分别登录不同桌面端，很容易出现“这台有记录、那台没
记录”的情况。本项目让所有设备都进入同一个持久化浏览器桌面，尽量避免产生新的
桌面端记录孤岛。

迁移旧数据时先停容器，再用 `rsync` 或 `scp` 拷贝：

```bash
docker compose --env-file .env -f compose/webtop-kde.yml down

scp -r old-host:/old/path/.xwechat \
  /path/to/KDE_in_WeBrowser/data/wechat/

scp -r old-host:/old/path/xwechat_files \
  /path/to/KDE_in_WeBrowser/data/wechat/
```

如果是大目录，建议用 `rsync -aH --info=progress2`，方便断点重试和保留元数据。
覆盖前先备份目标目录，避免误删已有聊天记录。

</details>

## Validation

Run before committing or after changing runtime behavior:

```bash
scripts/validate.sh
```

For a running local deployment:

```bash
VALIDATE_LIVE=1 scripts/validate.sh
```

The live check verifies the gateway, auth routing, running containers,
host-user compatibility, and KDE desktop processes.

## Documentation

- [Install](Doc/install.md)
- [Architecture](Doc/architecture.md)
- [WeChat/QQ data](Doc/wechat-qq.md)
- [Terminals](Doc/terminals.md)
- [Theme, locale, and DPI sync](Doc/theme-sync.md)
- [Bandwidth presets](Doc/bandwidth.md)
- [frpc](Doc/frpc.md)
- [Validation](Doc/validation.md)
- [Gateway](gateway/README.md)
- [PAM auth helper](gateway/pam-auth/README.md)

## Repository Hygiene

This repository should contain reusable code, templates, scripts, and public
documentation only. Runtime state, host credentials, frpc secrets, WeChat/QQ
data, TLS private keys, and local workflow notes are intentionally ignored.
