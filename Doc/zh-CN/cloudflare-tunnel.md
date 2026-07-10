# Cloudflare Tunnel

Cloudflare Tunnel 是 NAT、CGNAT、局域网-only 或 Tailscale-only 主机的可选暴
露方式。

向导支持两种模式：

- `cloudflare_named`：稳定域名，通过 Cloudflare API 创建和配置。
- `cloudflare_quick`：使用 `cloudflared tunnel --url` 生成临时公开 URL。

日常使用推荐 named tunnel。quick tunnel 适合短时间测试，因为 URL 不稳定。

## Named tunnel

运行向导：

```bash
scripts/deployment/configure.sh
```

网络检测为 `private_or_nat` 时选择：

```text
cloudflare_named
```

需要提供：

- Cloudflare API token
- Account ID
- Zone ID
- 公网 hostname，例如 `kde.example.com`
- tunnel name

API token 必须 active，并且对所选 account/zone 有权限。建议权限：

- Account 侧：Cloudflare Tunnel 或 Connector 写权限。
- Zone 侧：DNS 写权限。

向导会在写入最终配置前验证 token。验证失败时输入正确 token，或输入 `skip`。

验证通过后，`scripts/deployment/actions/setup-cloudflare-tunnel.sh` 会创建或复
用 named tunnel，写 ingress，创建/更新 DNS CNAME，获取 tunnel run token，并
写回 `.env`。

Compose profile：

```bash
docker compose --env-file .env -f compose/webtop-kde.yml --profile cloudflare up -d
```

## Quick tunnel

选择：

```text
cloudflare_quick
```

该 profile 运行：

```bash
cloudflared tunnel --url http://gateway-nginx:8080
```

它不需要 Cloudflare API token，也不会创建稳定域名，只适合临时测试。

## Origin URL

默认 origin：

```env
CLOUDFLARED_ORIGIN_URL=http://gateway-nginx:8080
```

这是 Docker 内部 HTTP origin，不应发布到宿主机或公网。它仍然经过同一套
PAM/Authelia 认证网关。
