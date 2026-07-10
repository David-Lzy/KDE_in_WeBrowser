# 网络和暴露方式

最安全的默认值是宿主机本地 HTTPS。远程访问只应该暴露认证网关，不应该暴露
Webtop 原始端口。

## 暴露方式

- `local`：只在宿主机本地浏览器访问。
- 局域网或 Tailscale：把网关绑定到可信私有设备可访问的地址。
- `frpc`：连接已有 frps 服务器，暴露网关 TLS 端口。
- `cloudflare_named`：通过 Cloudflare named tunnel 提供稳定域名。
- `cloudflare_quick`：Cloudflare 临时测试 URL。
- 公网 IP + ACME：公网主机使用 `sslip.io` 或自有域名加 Let's Encrypt。

## 选择建议

- 第一次启动和调试用本地模式。
- 客户端都在可信内网时，用局域网或 Tailscale。
- 已有 frps 和 token 时，用 frpc。
- 想要稳定域名且不想开放入站端口时，用 Cloudflare named tunnel。
- 只想临时测试时，用 Cloudflare quick tunnel。
- 机器有公网 IP 且公网 TCP 80 可达时，才用公网 ACME。

## 内部 HTTP origin

Cloudflare Tunnel 默认 origin：

```env
CLOUDFLARED_ORIGIN_URL=http://gateway-nginx:8080
```

这个监听只用于 Docker 内部 origin 流量，并且仍然走同一套认证网关。不要把它
发布到宿主机或互联网。
