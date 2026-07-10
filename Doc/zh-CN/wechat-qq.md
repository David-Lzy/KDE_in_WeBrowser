# 微信/QQ 模块

微信/QQ 模块是主 Webtop 镜像层的一部分。

构建并启动：

```bash
docker compose --env-file .env \
  -f compose/webtop-kde.yml \
  up -d --build
```

主 Compose 文件会构建 `modules/wechat-qq/Dockerfile`。该 Dockerfile 扩展 KDE
Webtop 基础镜像，并默认从 `ghcr.io/nickrunning/wechat-selkies:latest` 复制已
安装的微信/QQ 应用树，避免每次构建都重新下载新版安装包。

## 环境变量

- `ENABLE_WECHAT_QQ_MODULE`：默认 `true`。
- `INSTALL_WECHAT`：构建时安装微信，默认 `true`。
- `INSTALL_QQ`：构建时安装 QQ，默认 `true`。
- `INSTALL_PCMANFM`：安装 PCManFM 文件管理器，默认 `true`。
- `AUTO_START_WECHAT`：KDE 启动后自动启动微信，默认 `false`。
- `AUTO_START_QQ`：KDE 启动后自动启动 QQ，默认 `false`。

## 数据映射

模块不包含用户数据。请提供自己的宿主机目录：

- `WECHAT_PROFILE_DIR`：挂载到 `/config/.xwechat`。
- `WECHAT_FILES_DIR`：挂载到 `/wechat-xwechat-files`，并链接到微信读取的
  `/config/Documents/xwechat_files`。
- `QQ_DATA_DIR`：挂载到 `/config/Tencent Files`。

默认路径位于项目 ignored 的 `data/` 下：

```text
data/wechat/.xwechat
data/wechat/xwechat_files
data/qq/Tencent Files
```

不要提交这些目录。它们可能包含账号数据、聊天记录和接收文件。

## 为什么持久化映射重要

微信桌面端记录是本地客户端状态。如果你在多台电脑分别登录不同桌面端，每个安
装位置都可能有自己的 profile 和文件目录，所以常见现象是“这台有记录，那台没
记录”。

本项目让所有设备进入同一个远程 Linux 桌面 profile，减少这种割裂。它不会自动
合并彼此无关的旧历史，但可以提供一个稳定 profile 继续使用。

## 迁移聊天文件

先停止容器：

```bash
docker compose --env-file .env -f compose/webtop-kde.yml down
```

再复制旧数据：

```bash
rsync -aH --info=progress2 old-host:/old/path/.xwechat/ \
  /path/to/KDE_in_WeBrowser/data/wechat/.xwechat/

rsync -aH --info=progress2 old-host:/old/path/xwechat_files/ \
  /path/to/KDE_in_WeBrowser/data/wechat/xwechat_files/
```

小目录也可以用：

```bash
scp -r old-host:/old/path/.xwechat /path/to/KDE_in_WeBrowser/data/wechat/
scp -r old-host:/old/path/xwechat_files /path/to/KDE_in_WeBrowser/data/wechat/
```

覆盖已有目录前先备份。
