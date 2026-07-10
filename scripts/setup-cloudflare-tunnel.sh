#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

env_file=".env"
check_only=false

usage() {
  cat <<'EOF'
usage: scripts/setup-cloudflare-tunnel.sh [options]

Create or update a Cloudflare named tunnel from .env settings.

Options:
  --env-file PATH   Read and update this env file. Default: .env
  --check-only      Verify API token, account, zone, and DNS access only.
  -h, --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      env_file="${2:?missing env file path}"
      shift 2
      ;;
    --check-only)
      check_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "${env_file}" ]]; then
  echo "missing env file: ${env_file}" >&2
  exit 1
fi

KDE_CLOUDFLARE_ENV_FILE="${env_file}" \
KDE_CLOUDFLARE_CHECK_ONLY="${check_only}" \
python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ENV_FILE = Path(os.environ["KDE_CLOUDFLARE_ENV_FILE"])
CHECK_ONLY = os.environ.get("KDE_CLOUDFLARE_CHECK_ONLY") == "true"


class SetupError(RuntimeError):
    pass


def parse_env_value(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1]
    return value


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            values[key] = parse_env_value(value)
    return values


def quote_env_value(value: str) -> str:
    if value == "":
        return ""
    if re.search(r'[\s#"\\`$]', value):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return value


def update_env(path: Path, updates: dict[str, str]) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    seen: set[str] = set()
    new_lines: list[str] = []
    for line in lines:
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=", line)
        if match and match.group(1) in updates:
            key = match.group(1)
            new_lines.append(f"{key}={quote_env_value(updates[key])}")
            seen.add(key)
        else:
            new_lines.append(line)
    missing = [key for key in updates if key not in seen]
    if missing:
        if new_lines and new_lines[-1] != "":
            new_lines.append("")
        new_lines.append("# Cloudflare Tunnel runtime")
        for key in missing:
            new_lines.append(f"{key}={quote_env_value(updates[key])}")
    path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


env = load_env(ENV_FILE)


def value(key: str, default: str = "") -> str:
    override = os.environ.get(key)
    if override is not None and override != "":
        return override
    return env.get(key, default)


def required(key: str) -> str:
    result = value(key).strip()
    if not result or result == "__SKIP__":
        raise SetupError(f"{key} is required")
    return result


def bool_value(key: str, default: bool = True) -> bool:
    raw = value(key, "true" if default else "false").strip().lower()
    return raw in {"1", "true", "yes", "y", "on"}


api_base = value("CLOUDFLARE_API_BASE_URL", "https://api.cloudflare.com/client/v4").rstrip("/")
api_token = required("CLOUDFLARE_API_TOKEN")
account_id = required("CLOUDFLARE_ACCOUNT_ID")
zone_id = required("CLOUDFLARE_ZONE_ID")
hostname = required("CLOUDFLARE_HOSTNAME").strip().lower().rstrip(".")
tunnel_name = value("CLOUDFLARE_TUNNEL_NAME", "").strip() or value("COMPOSE_PROJECT_NAME", "kde-webtop")
origin_url = value("CLOUDFLARED_ORIGIN_URL", "http://gateway-nginx:8080").strip()
dns_proxied = bool_value("CLOUDFLARE_DNS_PROXIED", True)

if not hostname or "." not in hostname:
    raise SetupError("CLOUDFLARE_HOSTNAME must be a full hostname such as kde.example.com")
if not origin_url.startswith(("http://", "https://")):
    raise SetupError("CLOUDFLARED_ORIGIN_URL must start with http:// or https://")


def path_escape(raw: str) -> str:
    return urllib.parse.quote(raw, safe="")


def format_api_errors(payload: Any, status: int) -> str:
    if not isinstance(payload, dict):
        return f"HTTP {status}"
    parts: list[str] = []
    for item in payload.get("errors", []) or []:
        if isinstance(item, dict):
            code = item.get("code")
            message = item.get("message", item)
            parts.append(f"{code}: {message}" if code else str(message))
        else:
            parts.append(str(item))
    for item in payload.get("messages", []) or []:
        if isinstance(item, dict) and item.get("message"):
            parts.append(str(item["message"]))
    return "; ".join(parts) or f"HTTP {status}"


def cf_request(method: str, path: str, body: dict[str, Any] | None = None) -> Any:
    data = None
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Accept": "application/json",
    }
    if body is not None:
        data = json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(api_base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            status = response.status
            raw = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        status = exc.code
        raw = exc.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as exc:
        raise SetupError(f"Cloudflare API request failed: {exc}") from exc

    try:
        payload = json.loads(raw) if raw else {}
    except json.JSONDecodeError as exc:
        raise SetupError(f"Cloudflare API returned non-JSON response for {method} {path}") from exc

    success = bool(payload.get("success", 200 <= status < 300)) if isinstance(payload, dict) else 200 <= status < 300
    if not success:
        raise SetupError(f"Cloudflare API {method} {path} failed: {format_api_errors(payload, status)}")
    if isinstance(payload, dict):
        return payload.get("result")
    return payload


def ensure_token_active() -> None:
    result = cf_request("GET", "/user/tokens/verify")
    if isinstance(result, dict) and result.get("status") not in {None, "active"}:
        raise SetupError(f"Cloudflare API token status is {result.get('status')}")


def result_list(result: Any) -> list[dict[str, Any]]:
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    if isinstance(result, dict):
        for key in ("result", "tunnels", "records"):
            value = result.get(key)
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]
    return []


def list_tunnels() -> list[dict[str, Any]]:
    query = urllib.parse.urlencode({"name": tunnel_name, "is_deleted": "false"})
    result = cf_request("GET", f"/accounts/{path_escape(account_id)}/cfd_tunnel?{query}")
    return result_list(result)


def get_or_create_tunnel() -> str:
    tunnels = list_tunnels()
    for tunnel in tunnels:
        tunnel_id = str(tunnel.get("id", "")).strip()
        if tunnel_id:
            return tunnel_id

    result = cf_request(
        "POST",
        f"/accounts/{path_escape(account_id)}/cfd_tunnel",
        {"name": tunnel_name, "config_src": "cloudflare"},
    )
    if not isinstance(result, dict) or not result.get("id"):
        raise SetupError("Cloudflare tunnel create response did not include an id")
    return str(result["id"])


def configure_ingress(tunnel_id: str) -> None:
    cf_request(
        "PUT",
        f"/accounts/{path_escape(account_id)}/cfd_tunnel/{path_escape(tunnel_id)}/configurations",
        {
            "config": {
                "ingress": [
                    {
                        "hostname": hostname,
                        "service": origin_url,
                        "originRequest": {},
                    },
                    {"service": "http_status:404"},
                ]
            }
        },
    )


def list_dns_records() -> list[dict[str, Any]]:
    query = urllib.parse.urlencode({"name": hostname})
    result = cf_request("GET", f"/zones/{path_escape(zone_id)}/dns_records?{query}")
    return result_list(result)


def upsert_dns_record(tunnel_id: str) -> None:
    target = f"{tunnel_id}.cfargotunnel.com"
    records = list_dns_records()
    for record in records:
        if str(record.get("type", "")).upper() != "CNAME":
            raise SetupError(f"DNS name {hostname} already exists as {record.get('type')}; remove it or choose another hostname")

    body = {
        "type": "CNAME",
        "name": hostname,
        "content": target,
        "proxied": dns_proxied,
        "ttl": 1,
    }
    if records and records[0].get("id"):
        cf_request("PUT", f"/zones/{path_escape(zone_id)}/dns_records/{path_escape(str(records[0]['id']))}", body)
    else:
        cf_request("POST", f"/zones/{path_escape(zone_id)}/dns_records", body)


def get_tunnel_token(tunnel_id: str) -> str:
    result = cf_request("GET", f"/accounts/{path_escape(account_id)}/cfd_tunnel/{path_escape(tunnel_id)}/token")
    if not isinstance(result, str) or not result:
        raise SetupError("Cloudflare tunnel token response was empty")
    return result


def ensure_url_list(existing: str, public_url: str) -> str:
    urls = [item.strip() for item in existing.split(",") if item.strip()]
    if public_url not in urls:
        urls.append(public_url)
    return ",".join(urls)


try:
    ensure_token_active()
    list_tunnels()
    list_dns_records()

    if CHECK_ONLY:
        print(f"Cloudflare API check succeeded for {hostname}")
        sys.exit(0)

    tunnel_id = get_or_create_tunnel()
    configure_ingress(tunnel_id)
    upsert_dns_record(tunnel_id)
    tunnel_token = get_tunnel_token(tunnel_id)
    public_url = f"https://{hostname}"

    updates = {
        "EXPOSURE_METHOD": "cloudflare_named",
        "CLOUDFLARE_API_BASE_URL": api_base,
        "CLOUDFLARED_ORIGIN_URL": origin_url,
        "CLOUDFLARE_ACCOUNT_ID": account_id,
        "CLOUDFLARE_ZONE_ID": zone_id,
        "CLOUDFLARE_HOSTNAME": hostname,
        "CLOUDFLARE_TUNNEL_NAME": tunnel_name,
        "CLOUDFLARE_TUNNEL_ID": tunnel_id,
        "CLOUDFLARED_TUNNEL_TOKEN": tunnel_token,
        "CLOUDFLARE_DNS_PROXIED": "true" if dns_proxied else "false",
        "GATEWAY_PUBLIC_BASE_URL": public_url,
        "AUTHELIA_PUBLIC_BASE_URLS": ensure_url_list(value("AUTHELIA_PUBLIC_BASE_URLS", public_url), public_url),
    }
    update_env(ENV_FILE, updates)
    print(f"Cloudflare tunnel is configured for {public_url}")
except SetupError as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)
PY
