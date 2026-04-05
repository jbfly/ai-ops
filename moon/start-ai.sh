#!/bin/bash

# 1. Kill the Desktop on Alpha to reclaim VRAM
echo "🌑 Entering Headless Mode on Alpha..."
ssh jbfly@alpha "sudo systemctl stop plasmalogin"

# 2. Re-establish the tunnel (port 2455 for the proxy)
echo "🔗 Establishing Blackwell Bridge..."
ssh -C -N -L 2455:localhost:2455 jbfly@alpha &
TUNNEL_PID=$!

# 3. Env vars and Codex
export USER_TOKEN="vau-local"
export NOT_REQUIRED="true"
export USER="jbfly"

echo "🧠 AI Session Active. Press Ctrl+C to finish."
codex

# 4. Cleanup
kill $TUNNEL_PID
echo "🌙 Tunnel closed."

