# 公网域名和 ACME

安装向导会检测宿主机更像公网直连还是内网/NAT。

- `private_or_nat`：推荐 frpc 或 Cloudflare Tunnel，因为 Let's Encrypt
  HTTP-01 无法验证公网无法直连的服务。
- `public_direct`：可以配置公网 hostname 和自动 Let's Encrypt 证书。

## 公网直连模式

无需账号的推荐域名方式是 `sslip.io`。例如公网 IPv4 为 `203.0.113.10` 时，向
导会建议：

```text
kde-203-0-113-10.sslip.io
```

该域名会解析到嵌入的公网 IP。你也可以选择 `manual` 并输入自己的域名，只要 A
记录已经指向本机。

Let's Encrypt HTTP-01 要求公网 TCP 80 可达。ACME 模式下会设置：

```env
GATEWAY_BIND=0.0.0.0
GATEWAY_PORT=443
GATEWAY_PUBLIC_BASE_URL=https://your-domain
ACME_ENABLED=true
ACME_HTTP_PORT=80
```

Docker 仍然只发布认证后的 HTTPS 网关。Certbot standalone 会在申请和续期时临
时打开 TCP 80 完成 HTTP-01 challenge，然后关闭。

## 续期

`scripts/deployment/actions/setup-public-acme.sh` 会使用 Certbot standalone
HTTP-01 模式申请证书，把签发的 `fullchain.pem` 和 `privkey.pem` 复制到网关
TLS 路径，并 reload `gateway-nginx`。

当 `ACME_AUTO_RENEW=true` 时，脚本会安装：

```text
/etc/systemd/system/kde-webtop-acme-renew.service
/etc/systemd/system/kde-webtop-acme-renew.timer
/etc/letsencrypt/renewal-hooks/deploy/kde-webtop-*.sh
```

续期 hook 会调用 `scripts/deployment/actions/deploy-acme-cert.sh`，把新证书复
制回项目 `ssl/` 目录并 reload NGINX。

## 手动命令

`.env` 准备好且服务已启动后：

```bash
sudo scripts/deployment/actions/setup-public-acme.sh --env-file .env
```

重新部署已经签发的证书：

```bash
sudo scripts/deployment/actions/deploy-acme-cert.sh --env-file .env
```
