# Bandwidth Presets

The project exposes Selkies video settings through `.env`, so presets can be
selected without editing Compose files.

Available presets:

- `.env.low-bandwidth.example`
- `.env.balanced.example`
- `.env.quality.example`

Generate `.env`, then append one preset:

```bash
scripts/deployment/actions/detect-host-user.sh "$USER" > .env
cat .env.balanced.example >> .env
$EDITOR .env
```

## low-bandwidth

Use when latency and data use matter more than detail.

- Caps framerate at 30.
- Uses about 3 Mbps target video bitrate.
- Enables CSS scaling and keeps DPI at 96.
- Uses lower JPEG and paint-over quality.

## balanced

Default preset for normal personal remote desktop use.

- Allows up to 60 FPS.
- Uses about 8 Mbps target video bitrate.
- Keeps HiDPI physical resolution behavior.
- Keeps the full DPI list for browser DPR matching.

## quality

Use on reliable LAN/Tailscale links when clarity matters.

- Allows up to 120 FPS.
- Uses about 18 Mbps target video bitrate.
- Keeps HiDPI physical resolution behavior.
- Uses higher JPEG and paint-over quality.

## Important Variables

- `SELKIES_FRAMERATE`
- `SELKIES_VIDEO_BITRATE`
- `SELKIES_RATE_CONTROL_MODE`
- `SELKIES_ENABLE_RATE_CONTROL`
- `SELKIES_H264_CRF`
- `SELKIES_JPEG_QUALITY`
- `SELKIES_AUDIO_BITRATE`
- `SELKIES_USE_CSS_SCALING`
- `SELKIES_SCALING_DPI`
- `SELKIES_USE_PAINT_OVER_QUALITY`
- `SELKIES_PAINT_OVER_JPEG_QUALITY`
- `SELKIES_H264_PAINTOVER_CRF`
- `SELKIES_H264_PAINTOVER_BURST_FRAMES`
