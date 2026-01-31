#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/.devnet-status.json"

echo "=== Stopping CL8Y Fund Devnet ==="

if [ -f "$STATUS_FILE" ]; then
  ANVIL_PID=$(jq -r '.anvil_pid' "$STATUS_FILE" 2>/dev/null || echo "")
  VITE_PID=$(jq -r '.vite_pid' "$STATUS_FILE" 2>/dev/null || echo "")
  
  if [ -n "$VITE_PID" ]; then
    if kill "$VITE_PID" 2>/dev/null; then
      echo "Stopped Vite (PID: $VITE_PID)"
    else
      echo "Vite process already stopped"
    fi
  fi
  
  if [ -n "$ANVIL_PID" ]; then
    if kill "$ANVIL_PID" 2>/dev/null; then
      echo "Stopped Anvil (PID: $ANVIL_PID)"
    else
      echo "Anvil process already stopped"
    fi
  fi
  
  rm -f "$STATUS_FILE"
  rm -f "$SCRIPT_DIR/.anvil.log"
  rm -f "$SCRIPT_DIR/.vite.log"
  
  # Clean up frontend .env.local
  rm -f "$(dirname "$SCRIPT_DIR")/frontend/.env.local"
  
  echo "Devnet stopped and cleaned up"
else
  echo "No devnet status file found"
  echo "Attempting cleanup of any stray processes..."
  
  # Try to kill any anvil or vite processes
  pkill -f "anvil" 2>/dev/null && echo "Killed anvil process" || true
  pkill -f "vite.*fund" 2>/dev/null && echo "Killed vite process" || true
  
  echo "Cleanup complete"
fi
