#!/bin/bash
DESKTOP_IP="192.168.1.11"

echo "🛑 SHUTTING DOWN AI..."
ssh jbfly@$DESKTOP_IP "cd ~/git/ai-ops/alpha && docker compose down"

# Kill local tunnels on Moon
echo "✂️  Cutting local tunnels..."
fuser -k 8080/tcp 2>/dev/null
fuser -k 2455/tcp 2>/dev/null

echo "🖥️  RESTORING DESKTOP..."
ssh -t jbfly@$DESKTOP_IP "sudo systemctl start plasmalogin"
