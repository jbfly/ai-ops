# ai-ops

Small two-node workflow for running a remote `llama.cpp` server and driving it from local Codex.

## Topology

- `alpha/`: remote host ("brain") Docker Compose config for `llama.cpp`.
- `moon/`: local operator scripts to start/stop the remote stack, create SSH tunnel(s), and launch Codex.

## Prerequisites

- Local machine ("moon"):
  - Bash, `ssh`, `fuser`, `codex`
  - Network reachability to remote host
- Remote machine ("alpha"):
  - User `jbfly` reachable at `192.168.1.11` via SSH
  - Docker + Docker Compose
  - NVIDIA GPU runtime available to Docker
  - Model file present at `/home/jbfly/ai/models/gpt-oss-20b-mxfp4.gguf`

## Configuration

- [`moon/config.toml`](/home/jbfly/git/ai-ops/moon/config.toml) is intended to be symlinked to `~/.codex/config.toml`.
- The `oss` profile points Codex to the local OpenAI-compatible endpoint:
  - `base_url = "http://localhost:8080/v1"`
  - `model = "gpt-oss:20b"`

## Usage

- Start everything:
  - `bash moon/start-ai.sh`
- Stop everything:
  - `bash moon/stop-ai.sh`

## What Start Does

`moon/start-ai.sh` will:

1. Kill local process(es) on TCP `8080`.
2. SSH into `alpha`, stop existing compose stack, and stop several desktop services/processes.
3. Attempt GPU/process cleanup on the remote host.
4. Start `alpha/docker-compose.yml`.
5. Wait for `http://localhost:8080/health` to report `ok`.
6. Open local SSH tunnel `8080 -> alpha:8080`.
7. Launch `codex -p oss --dangerously-bypass-approvals-and-sandbox`.

## Safety Notes

- These scripts are environment-specific and currently hard-code:
  - Remote IP: `192.168.1.11`
  - Remote user: `jbfly`
  - Model path and service/process names
- `start-ai.sh` is operationally aggressive and can disrupt an active desktop session on the remote host.
- Run this only when you are intentionally switching the remote machine into headless "brain" mode.

## Known Limits

- No CI/test/lint/build workflow is defined in this repo.
- No multi-user safeguards are currently implemented in scripts.
