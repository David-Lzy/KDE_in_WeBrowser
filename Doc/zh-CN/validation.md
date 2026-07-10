# 验证

发布前运行：

```bash
scripts/validate.sh
```

脚本会检查 shell、Python、Compose 渲染、带宽预设、NGINX 网关配置、安装器和
部署向导 smoke、Cloudflare API mock、Authelia 配置，以及公开路径和 secret
扫描。它不会主动启停桌面。

如果已有本地部署在运行：

```bash
VALIDATE_LIVE=1 scripts/validate.sh
```

`VALIDATE_LIVE=1` 需要 `.env`。它会在存在 `compose.local.yml` 时一并包含，然
后检查 Compose 状态、HTTPS health endpoint，以及未登录的 HTTPS/WebSocket 请求
是否被重定向到登录。

## 手动浏览器检查

使用 `.env` 里的网关 URL，通常是 `https://127.0.0.1:18080`。

| 场景 | 期望 |
| --- | --- |
| 网关登录成功 | 正确用户名/密码进入桌面。 |
| 错误密码 | 显示认证错误。 |
| 未登录访问 Webtop | 重定向到登录页。 |
| KDE 启动 | Plasma 桌面进入可交互状态。 |
| 剪贴板浏览器到 KDE | 本地复制文本可粘贴进 KDE。 |
| 剪贴板 KDE 到浏览器 | KDE 复制文本可粘贴回本地。 |
| HiDPI/DPI 同步 | 浏览器比例变化后远程 DPI/scale 符合策略。 |
| 主题同步 | 浏览器暗色/亮色偏好可切换 KDE 主题。 |
| Host 终端 | 打开宿主机 shell。 |
| Docker 终端 | 打开容器内 shell。 |
| 微信/QQ | 启用后快捷方式可启动，数据落到 `/config` 映射目录。 |
| frpc/Cloudflare | 只暴露认证网关，不暴露 Webtop 原始端口。 |

发布前还应检查：

```bash
git status --short
git diff --check
git ls-files
```

公开文件不得包含 `.env`、`.agent/`、`.local/`、`_incoming/`、运行时
`config/`、微信/QQ 数据、真实 `frpc.toml`、token、TLS 私钥或大文件。
