# 宝塔/BT Panel

宝塔更适合读取单个 Compose 文件和完整 env 文件。正常项目结构会把 Compose
模板、`.env` 和可选 profile 分开，因此应在 `.env` 准备好后渲染宝塔专用文件：

```bash
scripts/deployment/actions/render-baota-compose.sh
```

输出文件：

```text
data/baota/docker-compose.yml
data/baota/.env
```

在宝塔里使用这两个文件。生成的 Compose 保留服务结构，`data/baota/.env` 包含
绝对路径和具体部署值。

## profiles

如果要包含额外暴露服务，渲染前设置 `BAOTA_COMPOSE_PROFILES`：

```bash
BAOTA_COMPOSE_PROFILES=frpc scripts/deployment/actions/render-baota-compose.sh
BAOTA_COMPOSE_PROFILES=cloudflare scripts/deployment/actions/render-baota-compose.sh
BAOTA_COMPOSE_PROFILES=cloudflare-quick scripts/deployment/actions/render-baota-compose.sh
```

不要把内部 HTTP origin `8080` 发布到宿主机。Cloudflare Tunnel 使用的
`http://gateway-nginx:8080` 只应该在 Docker 网络内部存在。

## 更新

修改 `.env` 后重新运行 renderer，并让宝塔重载生成的 Compose 文件。运行时数据
仍在 `data/home`、`data/wechat`、`data/qq`、`data/authelia` 等 ignored 路径。
