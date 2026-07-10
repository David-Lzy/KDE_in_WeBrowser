# 主题、语言和 DPI

主题同步会把 Selkies/浏览器状态映射到 KDE session：

- 浏览器 `prefers-color-scheme` 到 KDE Breeze light/dark。
- 浏览器 device pixel ratio 到 Selkies DPI 和 KDE scale 状态。
- 宿主用户语言到 KDE locale 和 Selkies HTML `lang` 属性。

容器启动时会安装：

- `/usr/local/bin/kde-webtop-theme-sync`
- 注入到 Selkies web root 的 `codex-theme-sync.js`

`custom-cont-init.d/55-kde-session-prefs.sh` 会根据 `WEBTOP_LANG`、
`WEBTOP_LANGUAGE` 和 `WEBTOP_LC_ALL` 写入 KDE locale。检测脚本优先读取宿主用
户的 `~/.config/plasma-localerc` 和 `~/.pam_environment`。

浏览器暗色/亮色变化会发送 Selkies command，运行：

```bash
/usr/local/bin/kde-webtop-theme-sync dark
/usr/local/bin/kde-webtop-theme-sync light
```

容器内手动命令：

```bash
kde-webtop-theme-sync dark
kde-webtop-theme-sync light
kde-webtop-theme-sync toggle
kde-webtop-theme-sync status
kde-webtop-scale-sync 144
kde-webtop-session-sync
kde-webtop-session-sync --restart-plasma
```

宿主机侧热加载：

```bash
scripts/reload-kde-session.sh
scripts/reload-kde-session.sh --restart-plasma
```

主题和 DPI 可以通过 Selkies command 热应用。locale 配置和 Selkies HTML
language 也可以实时改写，但已经运行的进程仍保留启动时环境。改语言后如需刷新
Plasma shell，可使用 `--restart-plasma`；完整重建 `webtop-kde` 最干净。
