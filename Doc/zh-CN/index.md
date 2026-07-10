# 中文文档索引

[返回中文 README](../../README.zh-CN.md) | [English docs](../en/index.md)

## 安装和部署

- [安装](install.md)：安装向导、全默认安装、本地文件和启动命令。
- [配置模型](configuration.md)：`.env`、`compose.local.yml`、profiles 和本地状态。
- [宝塔/BT Panel](baota.md)：生成面板可用的单个 Compose 文件和 env 文件。
- [宿主用户模式](host-user.md)：把宿主账号映射进项目本地桌面 home。

## 使用场景

- [微信/QQ](wechat-qq.md)：镜像层、数据挂载和聊天数据迁移。
- [远程 GUI](remote-gui.md)：无头/minimal Linux、服务器、实验室机器和 WSL 思路。
- [剪贴板和输入](clipboard-input.md)：浏览器剪贴板、Selkies 和 Wayland/Xwayland 文本桥。

## 远程访问

- [网络和暴露方式](networking.md)：本地、局域网、Tailscale、NAT、公网 IP 和选择建议。
- [frpc](frpc.md)：通过 frps 暴露认证后的 HTTPS 网关。
- [Cloudflare Tunnel](cloudflare-tunnel.md)：named tunnel 和 quick tunnel。
- [公网域名和 ACME](public-acme.md)：公网 IP、sslip.io/自有域名和 Let's Encrypt。

## 技术细节

- [架构](architecture.md)：组件和运行边界。
- [认证](auth.md)：PAM helper、Authelia fallback 和网关模型。
- [终端集成](terminals.md)：宿主机 SSH 终端和容器本地终端。
- [主题、语言和 DPI](theme-locale-dpi.md)：浏览器/用户状态同步到 KDE。
- [带宽预设](bandwidth.md)：Selkies 质量预设和变量。
- [验证](validation.md)：自动检查和手动浏览器清单。

## 相关参考

- [Compose 模板](../../compose/README.md)
- [网关细节](../../gateway/README.md)
- [PAM helper](../../gateway/pam-auth/README.md)
