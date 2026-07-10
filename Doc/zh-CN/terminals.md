# 终端集成

KDE 桌面在容器启动时创建两个终端入口：

- `Host SSH Terminal`：通过 SSH 连接选定宿主机用户。
- `Docker Terminal`：打开桌面容器内的本地 shell。

宿主机终端默认连接：

```text
${HOST_USER}@host.docker.internal:${HOST_SSH_PORT}
```

Linux Docker 下，Compose 通过 `host-gateway` 把 `host.docker.internal` 指到宿
主机。

## 环境变量

- `ENABLE_TERMINAL_INTEGRATION`：设为 `false` 可跳过终端集成。
- `HOST_SSH_HOST`：宿主机终端连接的 host/IP。
- `HOST_SSH_PORT`：SSH 端口，检测脚本会优先读取 `ssh.socket`。
- `HOST_SSH_TARGET`：完整 SSH target；留空时使用
  `${HOST_USER}@${HOST_SSH_HOST}`。
- `HOST_SSH_KEY`：容器内 SSH 私钥路径，默认
  `/config/.ssh/kde-webtop-host-ed25519`。
- `SYNC_HOST_TERMINAL_ASSETS`：安装时复制宿主机字体、fontconfig 和 Konsole
  配置到项目本地桌面 home。
- `SYNC_HOST_TERMINAL_SYSTEM_FONT_MATCHES`：复制 Konsole profile 引用到的系
  统字体文件。

配置免密 Host SSH：

```bash
scripts/deployment/actions/setup-host-ssh-key.sh
```

刷新字体和 Konsole 设置：

```bash
scripts/deployment/actions/sync-host-terminal-assets.sh
docker restart kde-webtop
```

Host 终端启动时会显示黄色 `HOST SSH terminal` banner，然后执行宿主机上的交互
式 `bash`，因此宿主机 `.bashrc` 和 oh-my-bash 等配置会生效。Docker 终端显示
青色 `DOCKER local terminal` banner，然后进入容器内 shell。
