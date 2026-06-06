# ai-ops

Local AI operations workspace.

## Hardware

Two GPUs:

- AMD GPU: desktop graphics
- NVIDIA RTX 5070 Ti: shared between local `llama.cpp`, AudioMuse analysis, and gaming

The AMD GPU drives the display. The NVIDIA GPU is managed by the arbiter in `llama-serve/`.

## Setup

The active control plane lives in `llama-serve/`.

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

## Deprecated

The old headless-mode experiment and the desktop/headless service split are in `archived/headless-mode/`.
Those files are kept for reference but are no longer used.
