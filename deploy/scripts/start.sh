#!/usr/bin/env bash
# start.sh - Start ttyd and app-tunnel-proxy.
# Usage: ./start.sh [-t TTYD_PORT] [-p PROXY_PORT] [-u USER:PASS]
#
# Starts ttyd (PTY) then app-tunnel-proxy (audit log + WS forwarding).
# Tailscale daemon is assumed to be already running (not managed here).
set -euo pipefail

# -- Defaults (override via flags or env) --
TTYD_PORT="${TTYD_PORT:-7681}"
PROXY_PORT="${PROXY_PORT:-8080}"
TTYD_CRED="${TTYD_CRED:-}"            # user:pass for ttyd basic auth
PROXY_BIN="${PROXY_BIN:-./server/app-tunnel-proxy}"
TTYD_BIN="${TTYD_BIN:-ttyd}"

usage() {
  cat <<EOF
Usage: $0 [-t TTYD_PORT] [-p PROXY_PORT] [-u USER:PASS] [-b PROXY_BIN]
  -t  ttyd listen port        (default: 7681)
  -p  proxy listen port       (default: 8080)
  -u  ttyd basic auth          (user:pass, required)
  -b  proxy binary path       (default: ./server/app-tunnel-proxy)
  -h  show this help
EOF
  exit 1
}

while getopts "t:p:u:b:h" opt; do
  case "$opt" in
    t) TTYD_PORT="$OPTARG" ;;
    p) PROXY_PORT="$OPTARG" ;;
    u) TTYD_CRED="$OPTARG" ;;
    b) PROXY_BIN="$OPTARG" ;;
    h|*) usage ;;
  esac
done

# -- Dependency checks --
check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: $1 not found. Install it first." >&2
    exit 1
  fi
}

check_command "$TTYD_BIN"

if [[ ! -x "$PROXY_BIN" ]]; then
  echo "ERROR: proxy binary not found or not executable: $PROXY_BIN" >&2
  echo "  Build it: (cd server && go build -o app-tunnel-proxy .)" >&2
  exit 1
fi

if [[ -z "$TTYD_CRED" ]]; then
  echo "ERROR: ttyd basic auth required. Use -u user:pass or set TTYD_CRED." >&2
  exit 1
fi

# -- Check for already running instances --
check_already_running() {
  local name="$1"
  if pgrep -f "$name" >/dev/null 2>&1; then
    echo "WARNING: $name appears to be already running." >&2
    echo "  Run stop.sh first, or check: pgrep -f $name" >&2
    exit 1
  fi
}

check_already_running "ttyd"
check_already_running "app-tunnel-proxy"

# -- Start ttyd --
echo "Starting ttyd on 127.0.0.1:$TTYD_PORT ..."
"$TTYD_BIN" \
  --port "$TTYD_PORT" \
  --interface 127.0.0.1 \
  --credential "$TTYD_CRED" \
  /bin/zsh &
TTYD_PID=$!
echo "  ttyd PID: $TTYD_PID"

# Brief pause to let ttyd bind its port.
sleep 1

if ! kill -0 "$TTYD_PID" 2>/dev/null; then
  echo "ERROR: ttyd failed to start." >&2
  exit 1
fi

# -- Start proxy --
echo "Starting app-tunnel-proxy on 127.0.0.1:$PROXY_PORT ..."
"$PROXY_BIN" \
  -listen "127.0.0.1:$PROXY_PORT" \
  -ttyd "http://127.0.0.1:$TTYD_PORT" &
PROXY_PID=$!
echo "  proxy PID: $PROXY_PID"

sleep 1

if ! kill -0 "$PROXY_PID" 2>/dev/null; then
  echo "ERROR: proxy failed to start. Stopping ttyd." >&2
  kill "$TTYD_PID" 2>/dev/null || true
  exit 1
fi

echo "All services started."
echo "  ttyd:  127.0.0.1:$TTYD_PORT  (PID $TTYD_PID)"
echo "  proxy: 127.0.0.1:$PROXY_PORT (PID $PROXY_PID)"
