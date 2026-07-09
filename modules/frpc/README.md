# frpc Module

This module stores sanitized frpc examples only. Real frpc configuration files
contain tokens and target server details, so they must stay outside Git.

To use the example:

```bash
cp modules/frpc/frpc.example.toml modules/frpc/frpc.toml
$EDITOR modules/frpc/frpc.toml
```

Keep `frpc.toml` ignored. Commit only redacted examples and documentation.

The example exposes only the authenticated gateway service:

```toml
localIP = "gateway-nginx"
localPort = 8080
```

Do not expose raw Webtop/Selkies ports through frpc.
