#!/usr/bin/env python3
from __future__ import annotations

import http.client
import json
import os
import socket
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


def load_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        env[key.strip()] = os.path.expandvars(value.strip())
    return env


CONFIG_DIR = Path.home() / ".config" / "llama-serve"
SETTINGS = load_env_file(CONFIG_DIR / "settings.env")
PROXY_HOST = SETTINGS.get("LLAMA_PROXY_HOST", "127.0.0.1")
PROXY_PORT = int(SETTINGS.get("LLAMA_PROXY_PORT", "8090"))
BACKEND_HOST = SETTINGS.get("LLAMA_BACKEND_HOST", "127.0.0.1")
BACKEND_PORT = int(SETTINGS.get("LLAMA_BACKEND_PORT", "8085"))
SERVER_UNIT = SETTINGS.get("LLAMA_SERVER_SYSTEMD_UNIT", "llama-server.service")
START_TIMEOUT = int(SETTINGS.get("LLAMA_START_TIMEOUT_SECONDS", "240"))
STATE_DIR = Path(os.path.expandvars(SETTINGS.get("LLAMA_STATE_DIR", str(Path.home() / ".local/state/llama-serve"))))
OWNER_FILE = STATE_DIR / "gpu-owner"
LAST_USED_FILE = STATE_DIR / "last-used"


def ensure_state_dir() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)


def now_ts() -> float:
    return time.time()


def touch_last_used() -> None:
    ensure_state_dir()
    LAST_USED_FILE.touch()
    os.utime(LAST_USED_FILE, None)


def get_owner() -> str:
    try:
        return OWNER_FILE.read_text().strip()
    except FileNotFoundError:
        return ""


def set_owner(owner: str) -> None:
    ensure_state_dir()
    if owner:
        OWNER_FILE.write_text(owner + "\n")
    elif OWNER_FILE.exists():
        OWNER_FILE.unlink()


def systemctl_user(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["systemctl", "--user", *args],
        check=check,
        text=True,
        capture_output=True,
    )


def service_is_active(unit: str) -> bool:
    result = systemctl_user("is-active", unit, check=False)
    return result.returncode == 0 and result.stdout.strip() == "active"


def stop_backend() -> None:
    systemctl_user("stop", SERVER_UNIT, check=False)


def start_backend() -> None:
    systemctl_user("start", SERVER_UNIT)


def backend_ready() -> bool:
    try:
        conn = http.client.HTTPConnection(BACKEND_HOST, BACKEND_PORT, timeout=2)
        conn.request("GET", "/health")
        resp = conn.getresponse()
        resp.read()
        conn.close()
        return resp.status < 500
    except OSError:
        return False


def ensure_backend_ready() -> None:
    if backend_ready():
        return
    start_backend()
    deadline = now_ts() + START_TIMEOUT
    while now_ts() < deadline:
        if backend_ready():
            return
        time.sleep(1)
    raise RuntimeError(f"backend did not become ready within {START_TIMEOUT} seconds")


def local_client(addr: tuple[str, int]) -> bool:
    host = addr[0]
    return host in {"127.0.0.1", "::1"}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}")

    def do_GET(self) -> None:
        self.dispatch_request(with_body=False)

    def do_POST(self) -> None:
        self.dispatch_request(with_body=True)

    def do_PUT(self) -> None:
        self.dispatch_request(with_body=True)

    def do_DELETE(self) -> None:
        self.dispatch_request(with_body=True)

    def do_PATCH(self) -> None:
        self.dispatch_request(with_body=True)

    def dispatch_request(self, *, with_body: bool) -> None:
        ensure_state_dir()
        if self.path == "/healthz":
            self.send_json(200, {
                "proxy": "ok",
                "backend_ready": backend_ready(),
                "backend_active": service_is_active(SERVER_UNIT),
                "owner": get_owner() or None,
            })
            return

        if self.path.startswith("/admin/"):
            self.handle_admin(with_body=with_body)
            return

        if not self.path.startswith("/v1/"):
            self.send_json(404, {"error": "not found"})
            return

        owner = get_owner()
        if owner and owner != "llama":
            self.send_json(503, {"error": {"message": f"GPU is reserved by {owner}"}})
            return

        touch_last_used()
        try:
            ensure_backend_ready()
            self.forward_request(with_body=with_body)
        except Exception as exc:  # noqa: BLE001
            self.send_json(503, {"error": {"message": f"LLM backend unavailable: {exc}"}})

    def handle_admin(self, *, with_body: bool) -> None:
        if not local_client(self.client_address):
            self.send_json(403, {"error": "admin endpoints require loopback"})
            return

        split = urlsplit(self.path)
        query = parse_qs(split.query)

        if split.path == "/admin/status":
            last_used = LAST_USED_FILE.stat().st_mtime if LAST_USED_FILE.exists() else None
            self.send_json(200, {
                "owner": get_owner() or None,
                "backend_active": service_is_active(SERVER_UNIT),
                "backend_ready": backend_ready(),
                "last_used_epoch": last_used,
                "proxy": {"host": PROXY_HOST, "port": PROXY_PORT},
                "backend": {"host": BACKEND_HOST, "port": BACKEND_PORT, "unit": SERVER_UNIT},
            })
            return

        owner = query.get("owner", [""])[0].strip()
        if not owner and with_body:
            length = int(self.headers.get("Content-Length", "0") or "0")
            if length:
                payload = json.loads(self.rfile.read(length))
                owner = str(payload.get("owner", "")).strip()

        if split.path == "/admin/acquire":
            if not owner:
                self.send_json(400, {"error": "owner is required"})
                return
            set_owner(owner)
            stop_backend()
            self.send_json(200, {"ok": True, "owner": owner})
            return

        if split.path == "/admin/release":
            current = get_owner()
            if owner and current and current != owner:
                self.send_json(409, {"error": f"owner mismatch: {current}"})
                return
            set_owner("")
            self.send_json(200, {"ok": True, "owner": None})
            return

        if split.path == "/admin/warm":
            current = get_owner()
            if current and current != "llama":
                self.send_json(409, {"error": f"GPU reserved by {current}"})
                return
            touch_last_used()
            try:
                ensure_backend_ready()
            except Exception as exc:  # noqa: BLE001
                self.send_json(503, {"error": str(exc)})
                return
            self.send_json(200, {"ok": True, "backend_ready": True})
            return

        self.send_json(404, {"error": "not found"})

    def forward_request(self, *, with_body: bool) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(content_length) if with_body and content_length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in {"host", "connection", "content-length"}}
        headers["Host"] = f"{BACKEND_HOST}:{BACKEND_PORT}"
        if body is not None:
            headers["Content-Length"] = str(len(body))

        conn = http.client.HTTPConnection(BACKEND_HOST, BACKEND_PORT, timeout=START_TIMEOUT)
        conn.request(self.command, self.path, body=body, headers=headers)
        resp = conn.getresponse()

        self.send_response(resp.status, resp.reason)
        for key, value in resp.getheaders():
            lowered = key.lower()
            if lowered in {"transfer-encoding", "connection"}:
                continue
            self.send_header(key, value)
        self.end_headers()

        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()
        conn.close()

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ensure_state_dir()
    server = ThreadingHTTPServer((PROXY_HOST, PROXY_PORT), Handler)
    server.serve_forever()
