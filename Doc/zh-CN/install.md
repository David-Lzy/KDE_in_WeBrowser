# 安装

推荐使用交互式向导：

```bash
scripts/deployment/configure.sh
```

向导会：

- 先询问中文或英文。
- 普通问题直接回车采用括号中的推荐值。
- 对 frpc token、frps 地址、Cloudflare API token、Authelia bootstrap
  password、额外挂载等敏感必填项，要求输入值或明确输入 `skip`。
- 写入本地 `.env`；只有配置额外挂载时才写入 `compose.local.yml`。
- 可选生成 TLS、安装 PAM helper、生成 Authelia 配置、同步终端字体和 Konsole
  配置、配置 Host SSH key、生成 frpc/Cloudflare 配置并启动 Compose。
- 检测网络形态。内网/NAT 可以选择本地、frpc、Cloudflare named tunnel 或
  quick tunnel；公网直连可以选择 `sslip.io` 或自有域名加 Let's Encrypt。

全默认的本地安装：

```bash
sudo scripts/deployment/configure.sh --language zh --defaults --force --start
```

这个模式适合新 clone 后快速在内网使用。它会生成 `.env`、本地 TLS，安装默认
PAM helper，启动 Compose，并在容器启动后配置容器到宿主机的 SSH key。

全默认模式不会猜测 frpc、Cloudflare 或公网 ACME 配置；这些需要你交互式提供
token/域名，或之后手动编辑本地 ignored 文件。

常用参数：

- `--language zh|en`
- `--defaults`
- `--no-actions`
- `--force`
- `--start`
- `--env-file PATH`
- `--compose-file PATH`
- `--frpc-file PATH`

临时 dry run：

```bash
tmpdir="$(mktemp -d)"
scripts/deployment/configure.sh \
  --language zh \
  --defaults \
  --force \
  --no-actions \
  --env-file "${tmpdir}/.env"
docker compose --env-file "${tmpdir}/.env" \
  -f compose/webtop-kde.yml \
  config --quiet
```

也可以使用简单非交互安装器：

```bash
scripts/deployment/install.sh --preset balanced
```

启动：

```bash
docker compose --env-file .env -f compose/webtop-kde.yml up -d
```

如果有 `compose.local.yml`，启动时加上：

```bash
docker compose --env-file .env \
  -f compose/webtop-kde.yml \
  -f compose.local.yml \
  up -d
```
