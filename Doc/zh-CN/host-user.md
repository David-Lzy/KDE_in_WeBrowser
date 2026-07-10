# 宿主用户模式

默认部署选择一个宿主机用户做认证和映射，但容器 `/config` 使用项目本地桌面
home，避免写入你的真实宿主机 home。

生成本地 `.env`：

```bash
scripts/deployment/actions/detect-host-user.sh "$USER" > .env
$EDITOR .env
```

重要字段：

- `HOST_USER`：选定宿主机账号。
- `HOST_UID`：LinuxServer `PUID` 使用的 UID。
- `HOST_GID`：LinuxServer `PGID` 使用的 GID。
- `HOST_HOME`：挂载为 `/config` 的项目本地宿主路径。
- `CONTAINER_USER`：容器内显示用户，通常是 `docker_${HOST_USER}`。
- `CONTAINER_HOSTNAME`：shell 和终端标题显示的 Docker hostname。

LinuxServer Webtop 仍保留内部 `abc` 账号。项目会添加 `CONTAINER_USER` 作为同
UID/GID、同 `/config` home 的 passwd/group/shadow 兼容账号，同时保留依赖
`s6-setuidgid abc` 的 LinuxServer 服务。

Compose 也会从 `CONTAINER_HOSTNAME` 设置 Docker hostname，所以终端提示符会显
示类似 `docker_davidli@docker_server2`，而不是随机容器 ID。
