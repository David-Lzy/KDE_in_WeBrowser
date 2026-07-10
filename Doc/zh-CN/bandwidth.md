# 带宽预设

项目通过 `.env` 暴露 Selkies 视频参数，因此可以不改 Compose 就切换预设。

可用预设：

- `.env.low-bandwidth.example`
- `.env.balanced.example`
- `.env.quality.example`

生成 `.env` 并追加预设：

```bash
scripts/deployment/actions/detect-host-user.sh "$USER" > .env
cat .env.balanced.example >> .env
$EDITOR .env
```

## low-bandwidth

适合更关心延迟和流量的环境。

- 帧率上限 30。
- 目标视频码率约 3 Mbps。
- 启用 CSS scaling，DPI 保持 96。
- 较低 JPEG 和 paint-over 质量。

## balanced

默认个人远程桌面预设。

- 最高 60 FPS。
- 目标视频码率约 8 Mbps。
- 保持 HiDPI 物理分辨率行为。
- 保留完整 DPI 列表，方便浏览器 DPR 匹配。

## quality

适合可靠局域网/Tailscale 链路。

- 最高 120 FPS。
- 目标视频码率约 18 Mbps。
- 保持 HiDPI 物理分辨率行为。
- 较高 JPEG 和 paint-over 质量。
