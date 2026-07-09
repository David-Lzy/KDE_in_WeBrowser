#!/usr/bin/env python3
"""Small HTTP-over-Unix-socket PAM auth helper for the Webtop gateway."""

from __future__ import annotations

import argparse
import base64
import ctypes
import ctypes.util
import hashlib
import hmac
import html
import json
import os
import secrets
import socket
import socketserver
import sys
import time
import urllib.parse
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PAM_PROMPT_ECHO_OFF = 1
PAM_PROMPT_ECHO_ON = 2
PAM_ERROR_MSG = 3
PAM_TEXT_INFO = 4
PAM_SUCCESS = 0
PAM_CONV_ERR = 19
PAM_BUF_ERR = 5


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def resolve_project_path(value: str, default: Path) -> Path:
    if not value:
        return default
    path = Path(value)
    if path.is_absolute():
        return path
    if value.startswith("../"):
        return (REPO_ROOT / "compose" / path).resolve()
    return (REPO_ROOT / path).resolve()


def bool_env(value: str, default: bool) -> bool:
    if value == "":
        return default
    return value.lower() in {"1", "true", "yes", "y", "on"}


def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode((data + padding).encode("ascii"))


class PamMessage(ctypes.Structure):
    _fields_ = [("msg_style", ctypes.c_int), ("msg", ctypes.c_char_p)]


class PamResponse(ctypes.Structure):
    _fields_ = [("resp", ctypes.c_void_p), ("resp_retcode", ctypes.c_int)]


PamConvFunc = ctypes.CFUNCTYPE(
    ctypes.c_int,
    ctypes.c_int,
    ctypes.POINTER(ctypes.POINTER(PamMessage)),
    ctypes.POINTER(ctypes.POINTER(PamResponse)),
    ctypes.c_void_p,
)


class PamConv(ctypes.Structure):
    _fields_ = [("conv", PamConvFunc), ("appdata_ptr", ctypes.c_void_p)]


class PamAuthenticator:
    def __init__(self, service: str):
        pam_path = ctypes.util.find_library("pam")
        if not pam_path:
            raise RuntimeError("libpam is not available on this host")
        libc_path = ctypes.util.find_library("c")
        if not libc_path:
            raise RuntimeError("libc is not available on this host")
        self.service = service.encode("utf-8")
        self.libpam = ctypes.CDLL(pam_path)
        self.libc = ctypes.CDLL(libc_path)
        self._configure_ctypes()

    def _configure_ctypes(self) -> None:
        self.libc.calloc.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
        self.libc.calloc.restype = ctypes.c_void_p
        self.libc.strdup.argtypes = [ctypes.c_char_p]
        self.libc.strdup.restype = ctypes.c_void_p

        self.libpam.pam_start.argtypes = [
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.POINTER(PamConv),
            ctypes.POINTER(ctypes.c_void_p),
        ]
        self.libpam.pam_start.restype = ctypes.c_int
        self.libpam.pam_authenticate.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.libpam.pam_authenticate.restype = ctypes.c_int
        self.libpam.pam_acct_mgmt.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.libpam.pam_acct_mgmt.restype = ctypes.c_int
        self.libpam.pam_end.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.libpam.pam_end.restype = ctypes.c_int

    def authenticate(self, username: str, password: str) -> bool:
        username_b = username.encode("utf-8")
        password_b = password.encode("utf-8")
        pamh = ctypes.c_void_p()

        @PamConvFunc
        def conversation(num_msg, msg, resp, appdata_ptr):
            if num_msg <= 0:
                return PAM_CONV_ERR
            response_ptr = self.libc.calloc(num_msg, ctypes.sizeof(PamResponse))
            if not response_ptr:
                return PAM_BUF_ERR
            responses = ctypes.cast(response_ptr, ctypes.POINTER(PamResponse))
            for index in range(num_msg):
                message = msg[index].contents
                if message.msg_style in (PAM_PROMPT_ECHO_OFF, PAM_PROMPT_ECHO_ON):
                    responses[index].resp = self.libc.strdup(password_b)
                    responses[index].resp_retcode = 0
                elif message.msg_style in (PAM_ERROR_MSG, PAM_TEXT_INFO):
                    responses[index].resp = None
                    responses[index].resp_retcode = 0
                else:
                    return PAM_CONV_ERR
            resp[0] = responses
            return PAM_SUCCESS

        conv = PamConv(conversation, None)
        status = self.libpam.pam_start(self.service, username_b, ctypes.byref(conv), ctypes.byref(pamh))
        if status != PAM_SUCCESS:
            return False
        try:
            status = self.libpam.pam_authenticate(pamh, 0)
            if status != PAM_SUCCESS:
                return False
            status = self.libpam.pam_acct_mgmt(pamh, 0)
            return status == PAM_SUCCESS
        finally:
            self.libpam.pam_end(pamh, status)


class AuthConfig:
    def __init__(self, env: dict[str, str], socket_path: Path, state_dir: Path):
        allowed = env.get("PAM_AUTH_ALLOWED_USERS") or env.get("PAM_AUTH_USER") or env.get("HOST_USER", "")
        self.allowed_users = {user.strip() for user in allowed.split(",") if user.strip()}
        if not self.allowed_users:
            raise RuntimeError("PAM_AUTH_ALLOWED_USERS or HOST_USER must be set")
        self.service = env.get("PAM_AUTH_SERVICE", "kde-webtop")
        self.cookie_name = env.get("PAM_AUTH_COOKIE_NAME", "kde_pam_session")
        self.session_ttl = int(env.get("PAM_AUTH_SESSION_TTL_SECONDS", "86400"))
        self.secure_cookie = bool_env(env.get("PAM_AUTH_SECURE_COOKIE", "true"), True)
        self.title = env.get("TITLE", "KDE in Web Browser")
        self.display_name = env.get("PAM_AUTH_DISPLAY_NAME", self.title)
        self.socket_path = socket_path
        self.state_dir = state_dir
        self.secret = self._load_or_create_secret()
        self.authenticator = PamAuthenticator(self.service)

    def _load_or_create_secret(self) -> bytes:
        self.state_dir.mkdir(parents=True, exist_ok=True)
        secret_path = self.state_dir / "session_secret"
        if secret_path.exists():
            return secret_path.read_bytes().strip()
        secret = secrets.token_hex(32).encode("ascii")
        secret_path.write_bytes(secret + b"\n")
        os.chmod(secret_path, 0o600)
        return secret

    def is_allowed_user(self, username: str) -> bool:
        return username in self.allowed_users

    def create_token(self, username: str) -> str:
        now = int(time.time())
        payload = {
            "u": username,
            "iat": now,
            "exp": now + self.session_ttl,
            "n": secrets.token_hex(8),
        }
        payload_data = b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
        signature = hmac.new(self.secret, payload_data.encode("ascii"), hashlib.sha256).digest()
        return f"{payload_data}.{b64url_encode(signature)}"

    def verify_token(self, token: str) -> str | None:
        try:
            payload_data, signature_data = token.split(".", 1)
            expected = hmac.new(self.secret, payload_data.encode("ascii"), hashlib.sha256).digest()
            if not hmac.compare_digest(expected, b64url_decode(signature_data)):
                return None
            payload = json.loads(b64url_decode(payload_data).decode("utf-8"))
            username = str(payload.get("u", ""))
            if int(payload.get("exp", 0)) < int(time.time()):
                return None
            if not self.is_allowed_user(username):
                return None
            return username
        except Exception:
            return None


class UnixHTTPServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True
    allow_reuse_address = True

    def server_bind(self):
        socketserver.UnixStreamServer.server_bind(self)
        os.chmod(self.server_address, 0o666)


class AuthHandler(BaseHTTPRequestHandler):
    server_version = "KDEPamAuth/1.0"

    @property
    def config(self) -> AuthConfig:
        return self.server.config  # type: ignore[attr-defined]

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.log_date_time_string(), fmt % args))

    def do_GET(self) -> None:
        path = urllib.parse.urlsplit(self.path).path
        if path == "/healthz":
            self._send_json(HTTPStatus.OK, {"ok": True, "auth": "pam"})
        elif path == "/auth/verify":
            self._handle_verify()
        elif path == "/auth/login":
            self._handle_login_page()
        elif path == "/auth/logout":
            self._clear_session("/")
        else:
            self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        path = urllib.parse.urlsplit(self.path).path
        if path == "/auth/login":
            self._handle_login_post()
        elif path == "/auth/logout":
            self._clear_session("/")
        else:
            self.send_error(HTTPStatus.NOT_FOUND)

    def _send_json(self, status: HTTPStatus, payload: dict[str, object]) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8") + b"\n"
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cookies(self) -> dict[str, str]:
        cookie_header = self.headers.get("Cookie", "")
        cookies: dict[str, str] = {}
        for item in cookie_header.split(";"):
            if "=" not in item:
                continue
            key, value = item.split("=", 1)
            cookies[key.strip()] = value.strip()
        return cookies

    def _safe_next(self, value: str | None) -> str:
        if not value:
            return "/"
        parsed = urllib.parse.urlsplit(value)
        if parsed.scheme or parsed.netloc:
            return "/"
        if not value.startswith("/") or value.startswith("//"):
            return "/"
        return value

    def _login_url(self) -> str:
        original = self._safe_next(self.headers.get("X-Original-URI"))
        return "/auth/login?" + urllib.parse.urlencode({"next": original})

    def _handle_verify(self) -> None:
        token = self._cookies().get(self.config.cookie_name, "")
        username = self.config.verify_token(token)
        if not username:
            self.send_response(HTTPStatus.UNAUTHORIZED)
            self.send_header("Location", self._login_url())
            self.end_headers()
            return
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Remote-User", username)
        self.send_header("Remote-Groups", "pam")
        self.send_header("Remote-Name", username)
        self.send_header("Remote-Email", f"{username}@localhost")
        self.end_headers()

    def _handle_login_page(self) -> None:
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
        next_url = self._safe_next(query.get("next", ["/"])[0])
        error = "error" in query
        default_user = sorted(self.config.allowed_users)[0] if len(self.config.allowed_users) == 1 else ""
        body = self._login_html(next_url, default_user, error).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _login_html(self, next_url: str, default_user: str, error: bool) -> str:
        title = html.escape(self.config.title)
        display = html.escape(self.config.display_name)
        next_value = html.escape(next_url, quote=True)
        user_value = html.escape(default_user, quote=True)
        error_html = '<p class="error">Username or password is incorrect.</p>' if error else ""
        return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <style>
    :root {{ color-scheme: dark; font-family: Inter, system-ui, sans-serif; }}
    body {{ margin: 0; min-height: 100vh; display: grid; place-items: center; background: #101418; color: #f6f7f8; }}
    main {{ width: min(420px, calc(100vw - 32px)); }}
    .mark {{ width: 72px; height: 72px; border-radius: 18px; display: grid; place-items: center; background: #55a99d; color: #102025; font-weight: 800; margin-bottom: 28px; }}
    h1 {{ margin: 0 0 8px; font-size: 32px; line-height: 1.1; }}
    p {{ margin: 0 0 22px; color: #b7c1c9; }}
    form {{ display: grid; gap: 14px; }}
    label {{ display: grid; gap: 6px; font-size: 14px; color: #c8d1d7; }}
    input {{ box-sizing: border-box; width: 100%; border: 1px solid #39444d; border-radius: 6px; background: #171d22; color: #f6f7f8; padding: 12px; font-size: 16px; }}
    button {{ border: 0; border-radius: 6px; background: #55a99d; color: #102025; padding: 12px; font-size: 16px; font-weight: 700; cursor: pointer; }}
    .error {{ color: #ffb4ab; margin: 0; }}
    .hint {{ margin-top: 18px; font-size: 13px; color: #8d9aa3; }}
  </style>
</head>
<body>
  <main>
    <div class="mark">KDE</div>
    <h1>{title}</h1>
    <p>{display}</p>
    <form method="post" action="/auth/login">
      <input type="hidden" name="next" value="{next_value}">
      <label>Username
        <input name="username" autocomplete="username" value="{user_value}" required autofocus>
      </label>
      <label>Password
        <input name="password" type="password" autocomplete="current-password" required>
      </label>
      {error_html}
      <button type="submit">Sign in</button>
    </form>
    <p class="hint">Host PAM authentication for this KDE Webtop.</p>
  </main>
</body>
</html>
"""

    def _handle_login_post(self) -> None:
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length > 16384:
            self.send_error(HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
            return
        fields = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8"), keep_blank_values=True)
        username = fields.get("username", [""])[0].strip()
        password = fields.get("password", [""])[0]
        next_url = self._safe_next(fields.get("next", ["/"])[0])
        if self.config.is_allowed_user(username) and self.config.authenticator.authenticate(username, password):
            token = self.config.create_token(username)
            cookie = f"{self.config.cookie_name}={token}; Path=/; HttpOnly; SameSite=Lax; Max-Age={self.config.session_ttl}"
            if self.config.secure_cookie:
                cookie += "; Secure"
            self.send_response(HTTPStatus.SEE_OTHER)
            self.send_header("Set-Cookie", cookie)
            self.send_header("Location", next_url)
            self.end_headers()
            return
        login_url = "/auth/login?" + urllib.parse.urlencode({"next": next_url, "error": "1"})
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header("Location", login_url)
        self.end_headers()

    def _clear_session(self, location: str) -> None:
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header(
            "Set-Cookie",
            f"{self.config.cookie_name}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0",
        )
        self.send_header("Location", location)
        self.end_headers()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", default=str(REPO_ROOT / ".env"))
    parser.add_argument("--socket")
    parser.add_argument("--state-dir")
    args = parser.parse_args()

    env = load_env_file(Path(args.env_file))
    socket_path = resolve_project_path(
        args.socket or env.get("PAM_AUTH_SOCKET_HOST", ""),
        resolve_project_path(env.get("PAM_AUTH_RUN_DIR", "../data/pam-auth/run"), REPO_ROOT / "data/pam-auth/run")
        / "pam-helper.sock",
    )
    state_dir = resolve_project_path(
        args.state_dir or env.get("PAM_AUTH_STATE_DIR", "../data/pam-auth/state"),
        REPO_ROOT / "data/pam-auth/state",
    )

    socket_path.parent.mkdir(parents=True, exist_ok=True)
    if socket_path.exists():
        socket_path.unlink()

    config = AuthConfig(env, socket_path, state_dir)
    server = UnixHTTPServer(str(socket_path), AuthHandler)
    server.config = config  # type: ignore[attr-defined]
    print(f"pam_auth_socket={socket_path}", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        try:
            socket_path.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
