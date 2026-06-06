# ai-ops

Local AI operations workspace.

## Current setup

The active setup is in `llama-serve/`.

Current assumption:
- the AMD GPU owns desktop graphics
- the NVIDIA GPU is shared between local `llama.cpp`, AudioMuse analysis, and occasional gaming

Normal client traffic goes to the local proxy on `127.0.0.1:8090`.
The raw `llama-server` backend stays on `127.0.0.1:8085` and starts only on demand.

Policy:
- first client request starts the backend
- idle timer stops it after the configured quiet period
- AudioMuse queue activity claims the GPU and stops the backend
- manual gaming mode can claim the GPU until released

Install and wire symlinks:

```bash
./llama-serve/install.sh
```

Read these first:
- `llama-serve/README.md`
- `docs/llama-arbiter.md`

## Archived setups

Old experiments are kept in `archived/` for reference:
- `archived/moon/` (old laptop/headless orchestration scripts)
- `archived/alpha/` (old docker/ollama stack)

These are deprecated. Do not treat them as active code paths.
