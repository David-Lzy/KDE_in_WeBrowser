# Remote GUI Scenarios

KDE in Web Browser is useful beyond WeChat/QQ. It can provide a browser-based
GUI layer for machines that normally do not have a desktop session.

## Headless or Minimal Linux

On a server or minimal installation, the stack gives you:

- KDE settings and file manager.
- Browser-accessible terminal shortcuts.
- Desktop apps that expect a graphical session.
- Clipboard and file workflows from any browser.
- Optional persistence under the project-local `data/` directory.

## Personal Server or Lab Machine

Use local HTTPS, LAN, Tailscale, frpc, or Cloudflare Tunnel depending on where
the machine lives. Keep the Webtop ports internal and expose only the gateway.

## Cloud VM

On a public VM, the wizard can offer `sslip.io` or a manual domain plus ACME if
public TCP port `80` is reachable. On NAT or CGNAT providers, use frpc or
Cloudflare Tunnel instead.

## WSL/WSL2

The project can be used as a Linux desktop-in-browser pattern when Docker and
networking are available. WSL environments vary: GPU acceleration, systemd,
host networking, and PAM behavior depend on the WSL distribution and Windows
configuration. Treat WSL as an optional advanced target, not the baseline.
