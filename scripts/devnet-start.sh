#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STATUS_FILE="$SCRIPT_DIR/.devnet-status.json"

echo "=== Starting CL8Y Fund Devnet ==="

# Check if already running
if [ -f "$STATUS_FILE" ]; then
  ANVIL_PID=$(jq -r '.anvil_pid' "$STATUS_FILE" 2>/dev/null || echo "")
  if [ -n "$ANVIL_PID" ] && kill -0 "$ANVIL_PID" 2>/dev/null; then
    echo "Devnet already running (Anvil PID: $ANVIL_PID)"
    echo "Use ./scripts/devnet-stop.sh to stop it first"
    jq '.' "$STATUS_FILE"
    exit 0
  else
    echo "Stale status file found, cleaning up..."
    rm -f "$STATUS_FILE"
  fi
fi

# Check dependencies
command -v anvil >/dev/null 2>&1 || { echo "Error: anvil not found. Install Foundry first."; exit 1; }
command -v forge >/dev/null 2>&1 || { echo "Error: forge not found. Install Foundry first."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found. Install jq first."; exit 1; }

# Start Anvil with 1-second block time
echo "Starting Anvil..."
anvil --block-time 1 > "$SCRIPT_DIR/.anvil.log" 2>&1 &
ANVIL_PID=$!
sleep 2

# Verify Anvil started
if ! kill -0 "$ANVIL_PID" 2>/dev/null; then
  echo "Error: Anvil failed to start. Check $SCRIPT_DIR/.anvil.log"
  exit 1
fi
echo "Anvil started (PID: $ANVIL_PID)"

# Deploy contracts
echo "Deploying contracts..."
cd "$PROJECT_ROOT/smartcontracts"

# Anvil account[0] private key
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

DEPLOY_OUTPUT=$(forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast 2>&1) || {
  echo "Error: Contract deployment failed"
  echo "$DEPLOY_OUTPUT"
  kill "$ANVIL_PID" 2>/dev/null
  exit 1
}

# Parse deployed addresses from output
USDT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "MockUSDT deployed at:" | awk '{print $NF}')
VAULT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "Vault deployed at:" | awk '{print $NF}')
TRANCHE_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "Tranche deployed at:" | awk '{print $NF}')

if [ -z "$TRANCHE_ADDR" ]; then
  echo "Error: Could not parse contract addresses from deployment output"
  echo "$DEPLOY_OUTPUT"
  kill "$ANVIL_PID" 2>/dev/null
  exit 1
fi

echo "Contracts deployed successfully"
echo "  MockUSDT: $USDT_ADDR"
echo "  Vault: $VAULT_ADDR"
echo "  Tranche: $TRANCHE_ADDR"

# Start frontend in test mode
echo "Starting frontend..."
cd "$PROJECT_ROOT/frontend"

# Write env file for frontend
cat > .env.local << EOF
VITE_TEST_MODE=true
VITE_DONATION_TRANCHE_ADDRESS=$TRANCHE_ADDR
VITE_DONATION_VAULT_ADDRESS=$VAULT_ADDR
VITE_USDT_ADDRESS=$USDT_ADDR
EOF

npm run dev > "$SCRIPT_DIR/.vite.log" 2>&1 &
VITE_PID=$!
sleep 3

# Verify Vite started
if ! kill -0 "$VITE_PID" 2>/dev/null; then
  echo "Error: Vite failed to start. Check $SCRIPT_DIR/.vite.log"
  kill "$ANVIL_PID" 2>/dev/null
  exit 1
fi
echo "Frontend started (PID: $VITE_PID)"

# Write status file
cat > "$STATUS_FILE" << EOF
{
  "running": true,
  "started_at": "$(date -Iseconds)",
  "anvil_pid": $ANVIL_PID,
  "vite_pid": $VITE_PID,
  "rpc_url": "http://localhost:8545",
  "frontend_url": "http://localhost:5173",
  "addresses": {
    "usdt": "$USDT_ADDR",
    "vault": "$VAULT_ADDR",
    "tranche": "$TRANCHE_ADDR"
  },
  "test_accounts": {
    "deployer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "user1": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "user2": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  }
}
EOF

echo ""
echo "=== Devnet Ready ==="
echo "Frontend: http://localhost:5173"
echo "Anvil RPC: http://localhost:8545"
echo "Status file: $STATUS_FILE"
echo ""
echo "Test wallet (auto-connected in test mode):"
echo "  Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "  Balance: 100,000 USDT"
echo ""
echo "Run ./scripts/devnet-stop.sh to stop"
