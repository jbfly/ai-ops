# llama-serve

Local `llama.cpp` control plane for a two-GPU desktop.

The AMD GPU drives the desktop.
The NVIDIA GPU is shared between local inference, AudioMuse analysis, and gaming.

## Layout

- proxy: `127.0.0.1:8090`
- backend: `127.0.0.1:8085`
- owner gate: `~/.local/state/llama-serve/gpu-owner`

Normal clients should hit the proxy. The proxy starts the backend on demand, blocks startup when another owner has the GPU, and updates idle state.

## Install

From repo root:

```bash
./llama-serve/install.sh
```

The installer creates symlinks for:
- `~/.config/llama-serve`
- user systemd units in `~/.config/systemd/user/`
- fish functions in `~/.config/fish/functions/`

It also enables:
- `llama-proxy.service`
- `llama-idle-stop.timer`
- `audiomuse-gpu-watch.timer`

## Model selection

Model definitions live in `models/*.env`.

Current model: `gemma4.env`.

Useful keys in a model env:
- `MODEL_PATH`: text GGUF
- `MMPROJ_PATH`: multimodal projector GGUF for image input
- `MMPROJ_OFFLOAD`: `on` or `off`
- `CTX_SIZE`: prompt context size
- `FLASH_ATTN`: `on`, `off`, or `auto`
- `BATCH_SIZE` / `UBATCH_SIZE`: cap compute buffer size
- `CACHE_TYPE_K` / `CACHE_TYPE_V`: KV cache quantization
- `REASONING`: `on`, `off`, or `auto`
- `IMAGE_MIN_TOKENS` / `IMAGE_MAX_TOKENS`: optional image token budget clamps
- `EXTRA_ARGS`: raw extra `llama-server` flags

Switch model:

```fish
ai-model gemma4
```

To add a model later, copy `models/gemma4.env.example` to a new file and fill in path/template.

## Commands

- `ai-warm`: clear manual locks and warm the backend through the proxy
- `ai-stop`: stop backend, keep proxy up
- `ai-game`: reserve GPU for games and stop backend
- `ai-auto`: release manual game lock
- `ai-status`: show service, timer, owner, and VRAM state
- `ai-model`: list or switch active model profile

## Notes

- `opencode-serve.service` is independent and can stay running.
- The old headless/desktop split is archived in `archived/headless-mode/`.
- See `../docs/llama-arbiter.md` for policy and client wiring.
- See `../README.md` for hardware assumptions.
