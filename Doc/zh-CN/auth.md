# 认证

浏览器入口是 `gateway-nginx`。它在代理到 Webtop 前使用 NGINX `auth_request`
做认证检查。

## PAM helper

默认 provider 是项目自带的宿主机 PAM helper。helper 运行在 Docker 宿主机上，
通过挂载到网关容器里的 Unix socket 验证选定 Linux 账号的 PAM 密码。

优点：

- 浏览器登录可以跟随宿主机账号密码。
- 容器不需要读取 `/etc/shadow`。
- 宿主机密码变化后，PAM 会实时生效，不需要重新生成 Authelia 用户文件。

安装器在权限足够时可以安装并启动 helper。手动说明见
[PAM auth helper README](../../gateway/pam-auth/README.md)。

## Authelia fallback

Authelia 仍可作为可选 file-user provider。它的 bootstrap password 是一次性值，
会被 hash 后写入 `data/authelia/users_database.yml`。这不是实时 PAM 同步。如
果想让登录跟随宿主机密码，请使用 PAM 模式。

## 网关边界

Webtop 原始端口留在 Docker 网络内部。无论使用本地 HTTPS、frpc、Cloudflare
Tunnel、局域网/Tailscale 还是公网 ACME，都应该把用户导向 gateway，而不是直连
Webtop。
