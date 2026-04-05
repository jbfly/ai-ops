#!/bin/bash

echo "🛑 Shutting down AI services on Alpha..."

# 1. Stop the Docker containers (Clean way)
ssh jbfly@alpha "cd ~/git/ai-ops/alpha && docker compose down"

# 2. Kill any 'manual' llama-server processes (Just in case!)
# We use -9 to make sure it releases the GPU memory immediately
ssh jbfly@alpha "pkill -9 llama-server"

echo "🖥️ Restarting Desktop Environment..."
# 3. Bring the GUI back
ssh jbfly@alpha "sudo systemctl start plasmalogin"

echo "✅ Alpha is back to 'Desktop Mode'. GPU is clear."







