# 配置模型

大多数部署行为由 `.env` 控制。Compose 模板保持通用，安装向导和脚本负责根据
当前宿主机生成本地值。

## 文件

- `.env`：主要本地配置文件，已被 Git 忽略。
- `compose.local.yml`：可选结构覆盖，通常只用于额外挂载，也被 Git 忽略。
- `modules/frpc/frpc.toml`：可选私有 frpc 配置，已被 Git 忽略。
- `data/`：默认项目本地运行时状态，包括桌面 home、微信/QQ 数据、Authelia
  配置、宝塔输出和生成资产。

## 重要配置组

- Compose 标识：`COMPOSE_PROJECT_NAME`、`CONTAINER_NAME`、
  `CONTAINER_HOSTNAME`。
- 宿主用户：`HOST_USER`、`HOST_UID`、`HOST_GID`、`HOST_HOME`、
  `CONTAINER_USER`。
- 网关：`GATEWAY_BIND`、`GATEWAY_PORT`、`GATEWAY_PUBLIC_BASE_URL`、
  `GATEWAY_AUTH_PROVIDER`、`GATEWAY_TLS_CERT`、`GATEWAY_TLS_KEY`。
- Selkies：剪贴板、编码器、码率、帧率、DPI 和缩放变量。
- 终端集成：`ENABLE_TERMINAL_INTEGRATION`、`HOST_SSH_*`、终端字体/配置同步。
- 微信/QQ：安装开关、自启动开关和数据目录。
- 暴露方式：`EXPOSURE_METHOD`、frpc 配置路径、Cloudflare Tunnel 和公网 ACME。

## Compose profiles

- 默认：Webtop、网关和认证服务。
- `frpc`：可选 frpc 客户端。
- `cloudflare`：Cloudflare named tunnel。
- `cloudflare-quick`：临时 Cloudflare quick tunnel。

只启用实际配置过的暴露 profile。

## 编辑原则

常规配置改 `.env`。只有需要改变 Compose 结构，例如额外挂载，才使用
`compose.local.yml`。不要把 token、密码、私钥或个人应用数据写进 tracked 文件。
