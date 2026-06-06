#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/jbfly/git/ai-ops"
REPO_LLAMA_DIR="$REPO_ROOT/llama-serve"
REPO_SYSTEMD_DIR="$REPO_ROOT/systemd"

CONFIG_DIR="$HOME/.config/llama-serve"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"

mkdir -p "$HOME/.config" "$SYSTEMD_USER_DIR" "$FISH_FUNCTIONS_DIR"

# Link ~/.config/llama-serve -> repo llama-serve dir.
if [[ -L "$CONFIG_DIR" ]]; then
  rm "$CONFIG_DIR"
elif [[ -e "$CONFIG_DIR" ]]; then
  echo "error: $CONFIG_DIR exists and is not a symlink" >&2
  echo "move it aside and rerun install.sh" >&2
  exit 1
fi
ln -s "$REPO_LLAMA_DIR" "$CONFIG_DIR"

# Link systemd units.
for unit in \
  llama-server.service \
  llama-proxy.service \
  llama-idle-stop.service \
  llama-idle-stop.timer \
  audiomuse-gpu-watch.service \
  audiomuse-gpu-watch.timer \
  llama-server-desktop.service \
  llama-server-headless.service
 do
  ln -sf "$REPO_SYSTEMD_DIR/$unit" "$SYSTEMD_USER_DIR/$unit"
 done

# Link fish functions.
for fn in ai-desktop ai-headless ai-stop ai-status ai-model ai-game ai-auto; do
  ln -sf "$REPO_LLAMA_DIR/fish/$fn.fish" "$FISH_FUNCTIONS_DIR/$fn.fish"
done

# Helper executables live under ~/.config/llama-serve via the config symlink.
chmod 0755 \
  "$REPO_LLAMA_DIR/llama_proxy.py" \
  "$REPO_LLAMA_DIR/idle_stop.py" \
  "$REPO_LLAMA_DIR/audiomuse_watch.py" \
  "$REPO_LLAMA_DIR/gpu-mode" \
  "$REPO_LLAMA_DIR/llama-serve"

# Ensure active model link exists.
if [[ ! -L "$CONFIG_DIR/active.env" && ! -e "$CONFIG_DIR/active.env" ]]; then
  ln -s "$CONFIG_DIR/models/gemma4.env" "$CONFIG_DIR/active.env"
fi

systemctl --user daemon-reload

systemctl --user enable --now llama-proxy.service llama-idle-stop.timer audiomuse-gpu-watch.timer >/dev/null

echo "installed llama-serve symlinks and systemd units"
echo "next:"
echo "  ai-desktop   # warm local model through the proxy"
echo "  ai-game      # release GPU for gaming"
echo "  ai-auto      # return to on-demand mode"
echo "  ai-status    # check proxy/backend/VRAM"

echo
read -r -p "remove legacy gemma4 wrapper/env files? [y/N] " cleanup
if [[ "$cleanup" =~ ^[Yy]$ ]]; then
  rm -f \
    "$HOME/.local/bin/llama-server-gemma4" \
    "$HOME/.config/opencode/gemma4.env" \
    "$HOME/.config/opencode/gemma4-gui.env" \
    "$HOME/.config/opencode/gemma4-headless.env"
  echo "legacy files removed"
else
  echo "legacy files kept"
fi
