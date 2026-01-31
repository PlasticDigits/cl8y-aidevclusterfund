#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/.devnet-status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "Devnet is NOT running"
  echo "(No status file found at $STATUS_FILE)"
  exit 1
fi

ANVIL_PID=$(jq -r '.anvil_pid' "$STATUS_FILE" 2>/dev/null || echo "")
VITE_PID=$(jq -r '.vite_pid' "$STATUS_FILE" 2>/dev/null || echo "")

ANVIL_RUNNING=false
VITE_RUNNING=false

if [ -n "$ANVIL_PID" ] && kill -0 "$ANVIL_PID" 2>/dev/null; then
  ANVIL_RUNNING=true
fi

if [ -n "$VITE_PID" ] && kill -0 "$VITE_PID" 2>/dev/null; then
  VITE_RUNNING=true
fi

if $ANVIL_RUNNING && $VITE_RUNNING; then
  echo "Devnet is RUNNING"
  echo ""
  jq '.' "$STATUS_FILE"
  exit 0
elif $ANVIL_RUNNING; then
  echo "Devnet is PARTIALLY running (Anvil up, Vite down)"
  jq '.' "$STATUS_FILE"
  exit 2
elif $VITE_RUNNING; then
  echo "Devnet is PARTIALLY running (Vite up, Anvil down)"
  jq '.' "$STATUS_FILE"
  exit 2
else
  echo "Devnet status file exists but processes are dead"
  echo "Run ./scripts/devnet-stop.sh to clean up, then ./scripts/devnet-start.sh"
  rm -f "$STATUS_FILE"
  exit 1
fi
