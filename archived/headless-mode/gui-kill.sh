#!/usr/bin/env bash
set -euo pipefail

SUDO_CMD=""
if sudo -n true 2>/dev/null; then
  SUDO_CMD="sudo -n"
elif [[ -t 0 ]]; then
  echo "sudo authentication required to stop display/login stack"
  if sudo -v; then
    SUDO_CMD="sudo"
  fi
fi

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
USER_NAME="$(id -un)"

# Stop system display/login stack.
if [[ -n "$SUDO_CMD" ]]; then
  $SUDO_CMD systemctl --no-block stop sunshine display-manager plasmalogin sddm greetd 2>/dev/null || true
else
  echo "warning: sudo unavailable; skipped stopping display/login stack"
fi

# Kill plasmalogin-helper first - this holds the active session so loginctl activate works later.
if [[ -n "$SUDO_CMD" ]]; then
  $SUDO_CMD pkill -f plasmalogin-helper 2>/dev/null || true
else
  pkill -f plasmalogin-helper 2>/dev/null || true
fi

# Stop user GUI services only. Keep opencode-serve running.
if ! timeout 12s systemctl --user --no-block stop sunshine dms.service niri.service 2>/dev/null; then
  if [[ -n "$SUDO_CMD" ]]; then
    timeout 12s $SUDO_CMD systemctl --machine="${USER_NAME}@" --user --no-block stop sunshine dms.service niri.service 2>/dev/null || true
  fi
fi

sleep 1
pkill -x ghostty 2>/dev/null || true
pkill -x qs 2>/dev/null || true
pkill -x waybar 2>/dev/null || true
pkill -x niri 2>/dev/null || true
pkill -x niriusd 2>/dev/null || true
pkill -x kwin_wayland 2>/dev/null || true
pkill -x plasmashell 2>/dev/null || true
pkill -x krunner 2>/dev/null || true
pkill -x xwayland-satellite 2>/dev/null || true
pkill -x Xwayland 2>/dev/null || true
pkill -x sunshine 2>/dev/null || true
