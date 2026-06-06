#!/usr/bin/env bash
set -euo pipefail

SUDO_CMD=""
if sudo -n true 2>/dev/null; then
  SUDO_CMD="sudo -n"
elif [[ -t 0 ]]; then
  echo "sudo authentication required to restore display/login stack"
  if sudo -v; then
    SUDO_CMD="sudo"
  fi
fi

if [[ -n "$SUDO_CMD" ]]; then
  # Kill plasmalogin-helper so plasmalogin drops the session and loginctl activate works.
  $SUDO_CMD pkill -f plasmalogin-helper 2>/dev/null || true

  systemctl --user stop dms.service niri.service sunshine.service 2>/dev/null || true
  pkill -x niri 2>/dev/null || true
  pkill -x xwayland-satellite 2>/dev/null || true
  pkill -x Xwayland 2>/dev/null || true

  # Restart display manager and activate seat0 to restore the greeter.
  $SUDO_CMD systemctl restart plasmalogin 2>/dev/null || $SUDO_CMD systemctl start display-manager plasmalogin sddm greetd 2>/dev/null || true

  seat_session="$(loginctl list-sessions --no-legend | awk '$4=="seat0"{print $1; exit}')"
  if [[ -n "$seat_session" ]]; then
    $SUDO_CMD loginctl activate "$seat_session" 2>/dev/null || true
  fi
else
  echo "warning: sudo unavailable; skipped restoring display/login stack"
fi

systemctl --user start sunshine 2>/dev/null || true
