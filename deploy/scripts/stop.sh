#!/usr/bin/env bash
# stop.sh - Stop ttyd and app-tunnel-proxy, then check for residuals.
# Usage: ./stop.sh
set -euo pipefail

stop_process() {
  local name="$1"
  local pids
  pids=$(pgrep -f "$name" 2>/dev/null || true)

  if [[ -z "$pids" ]]; then
    echo "$name: not running."
    return 0
  fi

  echo "Stopping $name (PIDs: $pids) ..."
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true

  # Wait up to 5 seconds for graceful shutdown.
  local waited=0
  while [[ $waited -lt 5 ]]; do
    if ! pgrep -f "$name" >/dev/null 2>&1; then
      echo "  $name stopped."
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  # Force kill if still alive.
  echo "  $name did not exit gracefully; sending SIGKILL ..."
  pids=$(pgrep -f "$name" 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
  fi
  echo "  $name killed."
}

# Stop in reverse order: proxy first, then ttyd.
stop_process "app-tunnel-proxy"
stop_process "ttyd"

# -- Residual check --
echo ""
echo "Residual check:"
residual=0

for name in "app-tunnel-proxy" "ttyd"; do
  if pgrep -f "$name" >/dev/null 2>&1; then
    echo "  WARNING: $name still running after stop attempt."
    pgrep -af "$name" || true
    residual=1
  fi
done

if [[ $residual -eq 0 ]]; then
  echo "  No residual processes found. Clean shutdown."
else
  echo "  Some processes may still be running. Check manually."
  exit 1
fi
