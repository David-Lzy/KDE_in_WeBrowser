# KDE in Web Browser

[English README](README.md) | [English docs](Doc/en/index.md) | [中文文档](Doc/zh-CN/index.md)

KDE in Web Browser 是一个运行在 Docker 里的持久化 KDE Plasma 桌面，通过
Selkies 在浏览器里显示，并由带认证的 HTTPS 网关保护。它适合把微信、QQ、剪
贴板同步、宿主机终端、远程 GUI 和常用桌面工具集中到一个长期运行的 Linux 桌
面里，然后从 Windows、macOS、Linux、平板或轻客户端用浏览器进入。

## 适合什么场景

- **所有设备共用一个微信/QQ桌面**：微信、QQ、接收文件、桌面设置和应用状态
  都保存在服务器上的同一个 Linux 桌面里，而不是散落在多台电脑的桌面客户端。
- **减少聊天记录割裂**：本项目不会自动合并彼此无关的旧聊天记录，但能让你后
  续都使用同一个远程桌面 profile，避免继续制造新的桌面端记录孤岛。
- **聊天数据就是普通文件**：微信/QQ profile 和文件目录都是宿主机挂载目录，可
  以用 `scp`、`rsync` 等普通工具备份和迁移。
- **剪贴板和输入更顺手**：浏览器剪贴板、Selkies 剪贴板和 Wayland/Xwayland
  文本剪贴板桥一起工作，让浏览器、KDE、微信、QQ 之间可以复制粘贴文本。输入
  法设置也集中在持久化 KDE 桌面里，不需要每台客户端重复配置。
- **给最小化 Linux 快速补一个 GUI**：无头服务器、minimal 云主机、实验室机器
  或个人工作站都可以快速拥有一个浏览器可访问的 KDE 桌面。
- **也可用于 WSL/WSL2 思路**：当 Docker 和网络条件满足时，可以作为浏览器里
  的 Linux 桌面工作流。GPU、systemd、宿主机集成能力取决于具体 WSL 环境。
- **多种远程访问方式**：本地、局域网/Tailscale、frpc、Cloudflare named
  tunnel、Cloudflare quick tunnel，以及公网 IP + ACME HTTPS。

## 主要能力

- 基于 LinuxServer Webtop 的 KDE Plasma Wayland 桌面。
- Selkies 浏览器串流，支持剪贴板、DPI 和窗口尺寸变化。
- 可选微信/QQ 镜像层，复用现有 `wechat-selkies` 应用资产。
- 默认使用宿主机 PAM helper 登录，也保留 Authelia 作为可选方案。
- Webtop 原始端口只留在 Docker 网络里，对外只发布认证后的 HTTPS 网关。
- 项目本地桌面 home 挂载为 `/config`，运行时数据不进入 Git。
- KDE 里内置宿主机 SSH 终端和容器本地终端入口。
- 浏览器/用户设置可同步到 KDE 的主题、语言和 DPI。
- 宝塔/BT Panel 可以生成单个 Compose 文件和完整 env 文件。
- 双语安装向导，支持推荐默认值和可选远程暴露配置。

## 快速开始

要求：

- Linux 宿主机，已安装 Docker 和 Docker Compose 插件。
- 足够的磁盘空间用于 KDE/Webtop 镜像和持久化桌面 home。
- 如果使用默认 PAM 登录，需要 `sudo` 或 root 权限安装宿主机 helper。

推荐交互式安装：

```bash
scripts/deployment/configure.sh
```

向导会先询问语言。普通问题直接回车采用推荐值。frpc token、Cloudflare API
token、Authelia bootstrap password 这类敏感必填项不能直接回车，需要输入值
或明确输入 `skip`。

全默认的本地内网安装：

```bash
sudo scripts/deployment/configure.sh --language zh --defaults --force --start
```

`--defaults` 会保持保守：不会自动启用 frpc、Cloudflare Tunnel 或公网 ACME，
因为脚本不能猜你的 token、域名或公网暴露意图。

启动后打开 `.env` 里的网关地址。默认本地地址通常是：

```text
https://127.0.0.1:18080
```

## 架构

```text
浏览器
  |
  | HTTPS、frpc、Cloudflare Tunnel、局域网或 Tailscale
  v
gateway-nginx  -- auth_request -->  PAM helper 或 Authelia
  |
  | 仅 Docker 内部网络
  v
kde-webtop  -- Selkies --> KDE Plasma Wayland
  |
  +-- 微信 / QQ
  +-- 宿主机 SSH 终端快捷方式
  +-- 剪贴板、主题、语言、DPI 同步脚本
```

默认不会发布 Webtop 原始端口。远程或公网访问应通过认证网关进入。

## 微信/QQ 数据

个人账号数据不会写进镜像。关键路径在 `.env` 里配置：

```env
WECHAT_PROFILE_DIR=/path/to/data/wechat/.xwechat
WECHAT_FILES_DIR=/path/to/data/wechat/xwechat_files
QQ_DATA_DIR="/path/to/data/qq/Tencent Files"
```

迁移旧数据时，先停止服务，再把旧目录复制到这些宿主机挂载目录：

```bash
docker compose --env-file .env -f compose/webtop-kde.yml down

rsync -aH --info=progress2 old-host:/old/path/.xwechat/ \
  /path/to/KDE_in_WeBrowser/data/wechat/.xwechat/

rsync -aH --info=progress2 old-host:/old/path/xwechat_files/ \
  /path/to/KDE_in_WeBrowser/data/wechat/xwechat_files/
```

小目录也可以用 `scp -r`。覆盖已有 profile 前请先备份目标目录。

## 文档

从这里开始：

- [English documentation index](Doc/en/index.md)
- [中文文档索引](Doc/zh-CN/index.md)

常用主题：

- [安装和部署](Doc/zh-CN/install.md)
- [配置模型](Doc/zh-CN/configuration.md)
- [微信/QQ 和聊天数据](Doc/zh-CN/wechat-qq.md)
- [剪贴板和输入](Doc/zh-CN/clipboard-input.md)
- [远程 GUI 场景](Doc/zh-CN/remote-gui.md)
- [网络和暴露方式](Doc/zh-CN/networking.md)
- [认证](Doc/zh-CN/auth.md)
- [Cloudflare Tunnel](Doc/zh-CN/cloudflare-tunnel.md)
- [公网域名和 ACME](Doc/zh-CN/public-acme.md)
- [验证](Doc/zh-CN/validation.md)

## 仓库边界

这个仓库只应该包含可复用代码、模板、脚本和公开文档。不要提交：

- `.env`、`compose.local.yml` 或生成的宝塔 env 文件
- 微信/QQ profile、聊天记录和接收文件
- frpc token、Cloudflare token、tunnel token
- TLS 私钥
- 运行时桌面 home、缓存、日志或导入的个人文件
- `.agent/`、`.local/` 等私有 agent 笔记
