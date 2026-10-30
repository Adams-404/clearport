#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/clearport-server"
TMP=$(mktemp -d)
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME" "$TMP/bin" "$XDG_CONFIG_HOME/clearport" "$XDG_STATE_HOME/clearport"
export PATH="$TMP/bin:$PATH"

cleanup() {
  sh "$SCRIPT" stop >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT HUP INT TERM

cat > "$TMP/bin/llama-server" <<'PY'
#!/usr/bin/env python3
import time
time.sleep(60)
PY
chmod +x "$TMP/bin/llama-server"
: > "$TMP/model.gguf"

cat > "$XDG_CONFIG_HOME/clearport/server.conf" <<EOF
MODEL_PATH="$TMP/model.gguf"
LLAMA_SERVER_BIN="llama-server"
HOST="127.0.0.1"
PORT="8080"
EOF

sh "$SCRIPT" start
sh "$SCRIPT" status
sh "$SCRIPT" start | grep -q "already running"
sh "$SCRIPT" stop

if sh "$SCRIPT" status >/dev/null 2>&1; then
  echo "Expected status to report a stopped server." >&2
  exit 1
fi

# A dead PID must be removed rather than mistaken for a running server.
echo 99999999 > "$XDG_STATE_HOME/clearport/llama-server.pid"
if sh "$SCRIPT" status >/dev/null 2>&1; then
  echo "Expected stale PID status to be non-zero." >&2
  exit 1
fi
test ! -e "$XDG_STATE_HOME/clearport/llama-server.pid"

# Missing models must fail before attempting to spawn the server.
cat > "$XDG_CONFIG_HOME/clearport/server.conf" <<EOF
MODEL_PATH="$TMP/missing.gguf"
LLAMA_SERVER_BIN="llama-server"
HOST="127.0.0.1"
PORT="8080"
EOF
if sh "$SCRIPT" start >/dev/null 2>&1; then
  echo "Expected a missing model to prevent startup." >&2
  exit 1
fi

echo "Termux launcher smoke tests passed (mock llama-server; host process lifecycle only)."
