#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys

SOCKET_PATH = os.environ.get("KDE_WEBTOP_PAM_SOCKET", "/run/kde-webtop-pam/helper.sock")
CHECKER = os.environ.get("KDE_WEBTOP_PAM_CHECKER", "/usr/local/libexec/kde-webtop-pam-check")
SOCKET_GROUP = os.environ.get("KDE_WEBTOP_PAM_SOCKET_GROUP", "docker")


def main():
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    set_socket_permissions()
    server.listen(20)

    while True:
        conn, _ = server.accept()
        with conn:
          handle(conn)


def set_socket_permissions():
    import grp

    try:
        gid = grp.getgrnam(SOCKET_GROUP).gr_gid
        os.chown(SOCKET_PATH, 0, gid)
    except KeyError:
        pass
    os.chmod(SOCKET_PATH, 0o660)


def handle(conn):
    raw = b""
    while not raw.endswith(b"\n") and len(raw) < 8192:
        chunk = conn.recv(4096)
        if not chunk:
            break
        raw += chunk

    try:
        data = json.loads(raw.decode("utf-8"))
        username = data["username"]
        password = data["password"]
        if not isinstance(username, str) or not isinstance(password, str):
            raise ValueError("invalid fields")
    except Exception:
        conn.sendall(b'{"ok":false,"error":"bad_request"}\n')
        return

    try:
        result = subprocess.run(
            [CHECKER, username],
            input=f"{password}\n",
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
            check=False,
        )
        ok = result.returncode == 0
        conn.sendall(json.dumps({"ok": ok}).encode("utf-8") + b"\n")
    except Exception:
        conn.sendall(b'{"ok":false,"unavailable":true}\n')


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
