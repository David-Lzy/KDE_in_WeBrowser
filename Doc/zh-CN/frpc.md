# frpc 暴露

frpc 是可选功能，默认关闭。

当网络检测结果是 `private_or_nat`，即局域网、CGNAT 或 Tailscale-only 主机，
安装向导会让你选择本地、frpc、Cloudflare named tunnel 或 quick tunnel。

手动启用：

```bash
cp modules/frpc/frpc.example.toml modules/frpc/frpc.toml
$EDITOR modules/frpc/frpc.toml
docker compose --env-file .env -f compose/webtop-kde.yml --profile frpc up -d
```

交互式向导也可以生成私有 frpc 文件：

```bash
scripts/deployment/configure.sh
```

启用 frpc 时，向导会要求输入 frps 地址和 token。这些字段不能直接回车；必须输
入值或明确输入 `skip`。如果选择自定义 frpc 配置路径，向导会把
`FRPC_CONFIG_FILE` 写入 `.env`，让 Compose 挂载准确文件。

只暴露认证网关：

```text
localIP = "gateway-nginx"
localPort = 8443
```

`8443` 是 gateway NGINX 的 TLS 监听。不要通过 frpc 暴露 Webtop 原始端口
`3000` 或 `3001`。

`modules/frpc/frpc.toml` 已被 Git 忽略，因为它包含真实 frps 地址、远程端口和
token。
