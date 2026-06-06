#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import time
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
state_dir = Path(os.path.expandvars(cfg.get("LLAMA_STATE_DIR", str(Path.home() / ".local/state/llama-serve"))))
owner_file = state_dir / "gpu-owner"
last_used_file = state_dir / "last-used"
idle_timeout = int(cfg.get("LLAMA_IDLE_TIMEOUT_SECONDS", "1800"))
unit = cfg.get("LLAMA_SERVER_SYSTEMD_UNIT", "llama-server.service")


def systemctl_user(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["systemctl", "--user", *args], text=True, capture_output=True, check=False)


owner = owner_file.read_text().strip() if owner_file.exists() else ""
if owner and owner != "llama":
    systemctl_user("stop", unit)
    raise SystemExit(0)

active = systemctl_user("is-active", unit)
if active.returncode != 0:
    raise SystemExit(0)

if not last_used_file.exists():
    systemctl_user("stop", unit)
    raise SystemExit(0)

idle_seconds = time.time() - last_used_file.stat().st_mtime
if idle_seconds >= idle_timeout:
    systemctl_user("stop", unit)
