#!/bin/bash
DESKTOP_IP="192.168.1.11"

echo "🧹 Cleaning Moon (Local Port 8080)..."
# We only need port 8080 now! Proxy is dead.
fuser -k 8080/tcp 2>/dev/null

echo "🌑 Stripping Alpha to Headless..."
# Run the cleanup in Bash on the remote end
ssh -t jbfly@$DESKTOP_IP 'bash -s' << 'EOF'
  echo "⏹️  Stopping current Brain & Desktop..."
  # Kill Docker containers FIRST to release VRAM
  cd ~/git/ai-ops/alpha && sudo docker compose down 2>/dev/null

  # Stop Desktop services (Catching both Wayland and X11)
  sudo systemctl stop sunshine plasmalogin sddm greetd 2>/dev/null
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  systemctl --user stop sunshine niri qs 2>/dev/null

  echo "🔫 Nuking persistent processes..."
  sudo pkill -9 -f "quickshell|sunshine|niri|firefox|beeper|alacritty|Xwayland|llama-server" 2>/dev/null
  sudo fuser -k /dev/nvidia* 2>/dev/null

  # Force Blackwell to drop memory pages
  sudo modprobe -r nvidia_uvm 2>/dev/null && sudo modprobe nvidia_uvm 2>/dev/null

  V_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | xargs)
  echo "VRAM Usage is now: ${V_USED}MiB (Target: <200MiB)"
EOF

echo "🧠 Waking the 20B Brain..."
# Make sure to use sudo here just in case your user isn't in the docker group on Alpha
ssh jbfly@$DESKTOP_IP "cd ~/git/ai-ops/alpha && sudo docker compose up -d"

echo -n "⏳ Waiting for 5070 Ti"
until ssh jbfly@$DESKTOP_IP "curl -s http://localhost:8080/health" | grep -q "ok"; do
    echo -n "."
    sleep 2
done
echo -e "\n✅ Brain Online."

echo "🔗 Tunneling 8080 (Direct to llama.cpp)..."
# Removed port 2455. Direct tunnel to the brain.
ssh -f -N -L 8080:localhost:8080 jbfly@$DESKTOP_IP
sleep 2 # Give tunnel a moment to handshake

echo "🚀 Opening Codex TUI..."
# Using the official 'oss' profile. No API keys or base URL exports needed!
codex -p oss --dangerously-bypass-approvals-and-sandbox

