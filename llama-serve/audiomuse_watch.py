#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import socket
import sys
import urllib.parse
import urllib.request
from pathlib import Path


def load_env(path: Path) -> dict[str, str]:
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


cfg = load_env(Path.home() / ".config" / "llama-serve" / "settings.env")
proxy_base = f"http://{cfg.get('LLAMA_PROXY_HOST', '127.0.0.1')}:{cfg.get('LLAMA_PROXY_PORT', '8090')}"
redis_host = cfg.get("AUDIOMUSE_WATCH_REDIS_HOST", "127.0.0.1")
redis_port = int(cfg.get("AUDIOMUSE_WATCH_REDIS_PORT", "16379"))
owner = cfg.get("AUDIOMUSE_WATCH_OWNER", "audiomuse")


def redis_command(*parts: str):
    payload = f"*{len(parts)}\r\n".encode()
    for part in parts:
        data = part.encode()
        payload += f"${len(data)}\r\n".encode() + data + b"\r\n"
    with socket.create_connection((redis_host, redis_port), 5) as sock:
        sock.sendall(payload)
        return read_resp(sock)


def read_resp(sock: socket.socket):
    def readline() -> bytes:
        buf = b""
        while not buf.endswith(b"\r\n"):
            chunk = sock.recv(1)
            if not chunk:
                raise EOFError("redis connection closed")
            buf += chunk
        return buf[:-2]

    line = readline()
    prefix, rest = line[:1], line[1:]
    if prefix == b"+":
        return rest.decode()
    if prefix == b":":
        return int(rest)
    if prefix == b"$":
        length = int(rest)
        if length == -1:
            return None
        data = b""
        while len(data) < length + 2:
            data += sock.recv(length + 2 - len(data))
        return data[:-2]
    if prefix == b"*":
        return [read_resp(sock) for _ in range(int(rest))]
    if prefix == b"-":
        raise RuntimeError(rest.decode())
    raise RuntimeError(f"unexpected redis response: {line!r}")


def queue_length(name: str) -> int:
    return int(redis_command("LLEN", f"rq:queue:{name}") or 0)


def worker_busy() -> bool:
    workers = redis_command("SMEMBERS", "rq:workers") or []
    for worker in workers:
        worker_name = worker.decode() if isinstance(worker, bytes) else str(worker)
        fields = redis_command("HGETALL", f"rq:worker:{worker_name}") or []
        mapping = {}
        for idx in range(0, len(fields), 2):
            key = fields[idx].decode() if isinstance(fields[idx], bytes) else str(fields[idx])
            value = fields[idx + 1].decode() if isinstance(fields[idx + 1], bytes) else str(fields[idx + 1])
            mapping[key] = value
        if mapping.get("state") and mapping["state"] != "idle":
            return True
    return False


def analysis_pending() -> bool:
    for queue in ("high", "default"):
        if queue_length(queue) > 0:
            return True
    return worker_busy()


def admin_call(action: str) -> None:
    url = f"{proxy_base}/admin/{action}?" + urllib.parse.urlencode({"owner": owner})
    req = urllib.request.Request(url, data=b"{}", method="POST")
    with urllib.request.urlopen(req, timeout=15) as resp:
        resp.read()


try:
    if analysis_pending():
        admin_call("acquire")
    else:
        admin_call("release")
except Exception as exc:  # noqa: BLE001
    print(f"audiomuse watch failed: {exc}", file=sys.stderr)
    raise SystemExit(1)
