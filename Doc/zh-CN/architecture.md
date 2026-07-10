# 架构

项目围绕一个浏览器可访问的 KDE 桌面组织，并可选安装应用模块。

## 基础桌面

当前基础桌面模板使用 LinuxServer Webtop：

- 镜像：`lscr.io/linuxserver/webtop:ubuntu-kde`
- 浏览器传输：Selkies，内部端口 `3000` 和 `3001`
- 桌面模式：KDE Wayland，并支持 Xwayland
- GPU 路径：`/dev/dri`，有 NVIDIA runtime 的宿主机可额外使用 NVIDIA

Compose 模板位于 `compose/webtop-kde.yml`。

浏览器入口是 `gateway-nginx`。它发布到宿主机，并通过 `auth_request` 请求配置
的认证 provider。默认 provider 是宿主机 PAM helper；Authelia 可作为可选
fallback。Webtop 原始端口默认不发布。

## Init 扩展

自定义 init 脚本挂载到 `/custom-cont-init.d`：

- `50-xwayland-clipboard-bridge.sh`：同步 Wayland 原生应用和 Xwayland 应用的
  文本剪贴板。
- `55-kde-session-prefs.sh`：写入 KDE 语言/session 默认值，并安装 KDE scale
  sync 命令。
- `60-auto-hidpi-dpi.sh`：注入客户端 DPI 选择，让 Selkies 根据浏览器 DPR 匹配
  stream DPI 和 KDE scale。

## 可选模块

- `modules/wechat-qq/`：微信/QQ 镜像层、launcher 脚本和默认设置。
- `modules/frpc/`：通过远程 frps 暴露认证网关的 sanitized 示例。真实 token
  和服务端信息属于本地部署数据，不进入 Git。
