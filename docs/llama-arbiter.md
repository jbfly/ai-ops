# llama arbiter and local proxy

This tree owns the local `llama.cpp` control plane on `alpha`.

## Goal

Keep one stable local OpenAI-compatible endpoint on `127.0.0.1:8090`.
That endpoint should:

- start `llama-server` on first demand
- stop it after an idle window
- refuse or preempt it when the GPU is reserved for another owner
- mirror AudioMuse queue activity into GPU ownership

The raw backend stays on `127.0.0.1:8085` and is not the normal client entry point.

## Ports

- proxy: `127.0.0.1:8090`
- backend: `127.0.0.1:8085`

Clients should target the proxy.

## Files

- `llama-serve/llama_proxy.py`: HTTP proxy and owner gate
- `llama-serve/idle_stop.py`: idle-stop check
- `llama-serve/audiomuse_watch.py`: polls AudioMuse Redis state through the existing alpha tunnel
- `llama-serve/gpu-mode`: local admin helper
- `llama-serve/settings.env`: shared local policy knobs
- `systemd/llama-server.service`: raw backend
- `systemd/llama-proxy.service`: on-demand proxy
- `systemd/llama-idle-stop.timer`: idle reap timer
- `systemd/audiomuse-gpu-watch.timer`: AudioMuse activity mirror

## Owner model

Owner state is stored under `~/.local/state/llama-serve/`.

Current owners:

- empty: no reservation; proxy may start backend on demand
- `audiomuse`: AudioMuse queue owns the GPU
- `game`: manual gaming override

If an owner is set, the proxy returns `503` for LLM traffic instead of starting the backend.

## AudioMuse integration

The watcher does not call the AudioMuse web UI.
It reads the existing Redis queue state over the secure localhost tunnel already used by the remote worker.
If AudioMuse has queued or busy work, the watcher acquires owner `audiomuse` and stops `llama-server`.
When the queue drains, it releases that owner.

This keeps Redis and Postgres off the LAN and avoids coupling to Traefik/AuthentiK.

## Install

From repo root:

```sh
./llama-serve/install.sh
```

That does four things:

1. links `~/.config/llama-serve` to this repo
2. installs helper executables into that config tree
3. links user systemd units
4. enables and starts:
   - `llama-proxy.service`
   - `llama-idle-stop.timer`
   - `audiomuse-gpu-watch.timer`

## Service graph

- `llama-proxy.service` is the steady-state front door
- `llama-server.service` starts only when the proxy needs it
- `llama-idle-stop.timer` stops the backend after `LLAMA_IDLE_TIMEOUT_SECONDS`
- `audiomuse-gpu-watch.timer` reserves the GPU while AudioMuse work is queued or running

## Operator commands

Fish helpers:

- `ai-desktop`: clear manual lock and warm backend
- `ai-stop`: stop backend only
- `ai-game`: reserve GPU for gaming and stop backend
- `ai-auto`: release manual game lock
- `ai-status`: show proxy/backend/timer state

Raw helper:

```sh
~/.config/llama-serve/gpu-mode status
~/.config/llama-serve/gpu-mode warm
~/.config/llama-serve/gpu-mode game
~/.config/llama-serve/gpu-mode auto
```

## Client wiring

### beeper-bot

Use:

```toml
[llm]
base_url = "http://127.0.0.1:8090/v1"
model = "gemma4-google-26b-a4b-q4_0-local"
```

### Pi coding agent

`~/.pi/agent/models.json` should point the local provider at:

```json
{
  "providers": {
    "llama.cpp": {
      "baseUrl": "http://127.0.0.1:8090/v1"
    }
  }
}
```

Keep `supportsDeveloperRole=false` and `supportsReasoningEffort=false` for `llama.cpp` OpenAI compatibility.

## Notes for future agents

- Do not point local clients at `8085` unless you are debugging the backend itself.
- Use `8090` for normal work.
- Do not expose either port on the LAN.
- If AudioMuse analysis unexpectedly coexists with the backend, inspect:
  - `systemctl --user status audiomuse-gpu-watch.timer`
  - `systemctl --user status audiomuse-gpu-watch.service`
  - `curl -fsS http://127.0.0.1:8090/admin/status`
- If clients get `503 GPU is reserved`, check owner state before forcing a start.
