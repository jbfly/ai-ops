#!/bin/bash

# 1. Clear any manual models and the Desktop
echo "🌑 Clearing GPU and entering Headless Mode..."
ssh jbfly@alpha "pkill -9 llama-server; sudo systemctl stop plasmalogin"

# 2. Start the Docker containers
echo "🚀 Launching AI Brain (Docker)..."
ssh jbfly@alpha "cd ~/git/ai-ops/alpha && docker compose up -d"

# 3. Establish the tunnel
ssh -C -N -L 2455:localhost:2455 jbfly@alpha &
TUNNEL_PID=$!

# 4. Launch Codex
export USER_TOKEN="vau-local"
export NOT_REQUIRED="true"
codex

# 5. Cleanup Tunnel
kill $TUNNEL_PID
echo "🌙 Session finished. Run './stop-ai.sh' to restore the desktop."
