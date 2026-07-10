# 远程 GUI 场景

KDE in Web Browser 不只是微信/QQ 容器。它也可以给平时没有桌面的机器提供一个
浏览器访问的 GUI 层。

## 无头或 minimal Linux

在服务器或最小化系统上，它可以提供：

- KDE 设置界面和文件管理器。
- 浏览器可访问的终端快捷方式。
- 需要图形会话的桌面应用。
- 从任意浏览器使用的剪贴板和文件工作流。
- 落在项目本地 `data/` 目录下的持久化状态。

## 个人服务器或实验室机器

根据机器所在网络，选择本地 HTTPS、局域网、Tailscale、frpc 或 Cloudflare
Tunnel。保持 Webtop 原始端口只在 Docker 内部，对外只暴露网关。

## 云主机

如果云主机有公网 IP 且公网 TCP 80 可达，向导可以配置 `sslip.io` 或自有域名加
ACME。NAT/CGNAT 云主机更适合 frpc 或 Cloudflare Tunnel。

## WSL/WSL2

当 Docker 和网络条件满足时，也可以把它当成 WSL/WSL2 风格的“浏览器里的 Linux
桌面”。不同 WSL 环境差异很大：GPU、systemd、宿主网络和 PAM 行为都取决于具
体发行版和 Windows 配置。把 WSL 视为进阶目标，而不是默认基线。
