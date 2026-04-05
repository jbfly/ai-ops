#!/bin/bash
DESKTOP_IP="192.168.1.11"

echo "🧹 Cleaning Moon (Local Port 8080 & 2455)..."
fuser -k 8080/tcp 2>/dev/null
fuser -k 2455/tcp 2>/dev/null

echo "🌑 Stripping Alpha to Headless..."
# Run the cleanup in Bash on the remote end
ssh -t jbfly@$DESKTOP_IP 'bash -s' << 'EOF'
  echo "⏹️  Stopping current Brain & Desktop..."
  # Kill Docker containers FIRST to release VRAM
  cd ~/git/ai-ops/alpha && sudo docker compose down 2>/dev/null
  
  # Stop Desktop services
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
ssh jbfly@$DESKTOP_IP "cd ~/git/ai-ops/alpha && docker compose up -d"

echo -n "⏳ Waiting for 5070 Ti"
until ssh jbfly@$DESKTOP_IP "curl -s http://localhost:8080/health" | grep -q "ok"; do
    echo -n "."
    sleep 2
done
echo -e "\n✅ Brain Online."

echo "🔗 Tunneling 8080 & 2455..."
ssh -f -N -L 8080:localhost:8080 -L 2455:localhost:2455 jbfly@$DESKTOP_IP

echo "🚀 Opening Codex TUI..."
export OPENAI_API_KEY="sk-vau-local" 
export CODEX_API_BASE="http://localhost:2455/v1"

codex --profile vau-ops --dangerously-bypass-approvals-and-sandbox

