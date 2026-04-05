#!/bin/bash
# Clear old tunnels
pkill -f "ssh.*L 2455:localhost:2455"

# Start the tunnel to alpha (Desktop)
ssh -C -N -L 2455:localhost:2455 jbfly@192.168.1.11 &
TUNNEL_PID=$!

# Environment tricks for Codex v0.118.0
export USER_TOKEN="vau-local"
export NOT_REQUIRED="true"

echo "🧠 Connecting to 5070 Ti... Launching Codex!"
codex

# Cleanup
kill $TUNNEL_PID
