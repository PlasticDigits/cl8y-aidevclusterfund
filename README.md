# CL8Y Fund

Private, invite-only fundraising platform for AI dev cluster infrastructure.

**Live Site**: fund.cl8y.com

## Overview

CL8Y Fund enables the CL8Y community to contribute USDT toward AI inference infrastructure costs. Contributors receive NFT "Donation Notes" with 30% APR rewards, matched 1:1 by the CZodiac vault.

## Documentation

- [PROPOSAL.md](PROPOSAL.md) - High-level design document covering architecture, user stories, and economic model
- [SPRINT2.md](SPRINT2.md) - Sprint 1 handoff document with implementation notes and known issues
- [SPRINT3.md](SPRINT3.md) - Sprint 2 handoff document with devnet testing recommendations
- [SPRINT4.md](SPRINT4.md) - Sprint 3 handoff document with marketplace, repayment UI, and E2E testing scope

## Project Structure

```
fund/
├── frontend/          # React + Vite + Tailwind frontend
├── smartcontracts/    # Foundry smart contracts
├── scripts/           # Devnet start/stop/status scripts
├── PROPOSAL.md        # Detailed project proposal
├── SPRINT2.md         # Sprint 1 handoff documentation
├── SPRINT3.md         # Sprint 2 handoff documentation
└── SPRINT4.md         # Sprint 3 handoff documentation
```

## Smart Contracts

### DonationTranche.sol
- Manages 2-week fundraising tranches
- Mints ERC721 donation note NFTs
- Coordinates 1:1 matching with vault
- Handles repayments (interest first, then principal)

### DonationMatchVault.sol
- Holds USDT for matching contributions
- Owned by CZodiac multisig
- Accumulates matched NFT donation notes

### Addresses (BSC)
- AccessManager: `0x5823a01A5372B779cB091e47DBBb176F2831b4c7`
- USDT: `0x55d398326f99059fF775485246999027B3197955`
- Cluster Manager: `0x30789c78b7640947db349e319991aaec416eeb93`
- Vault Owner: `0x745A676C5c472b50B50e18D4b59e9AeEEc597046`

## Development

### Smart Contracts

```bash
cd smartcontracts

# Install dependencies
forge install

# Build
forge build

# Test
forge test

# Deploy (requires PRIVATE_KEY env var)
forge script script/Deploy.s.sol --rpc-url bsc --broadcast
```

### Frontend

```bash
cd frontend

# Install dependencies
npm install

# Development server
npm run dev

# Build for production
npm run build
```

## Environment Variables

### Smart Contracts

| Variable | Description |
|----------|-------------|
| `PRIVATE_KEY` | Deployer wallet private key (without 0x prefix) |

### Frontend

| Variable | Description |
|----------|-------------|
| `VITE_DONATION_TRANCHE_ADDRESS` | Deployed DonationTranche contract address |
| `VITE_DONATION_VAULT_ADDRESS` | Deployed DonationMatchVault contract address |

## Testing

### Smart Contracts

```bash
cd smartcontracts

# Run all tests with verbosity
forge test -vv

# Run specific tests
forge test --match-test Deposit -vv

# Generate coverage report
forge coverage
```

### Frontend

```bash
cd frontend

# Start development server
npm run dev

# Build and preview production
npm run build
npm run preview
```

## Deployment

### Pre-Deployment Checklist

- [ ] Review contract code for any changes
- [ ] Verify all tests pass (`forge test -vv`)
- [ ] Confirm addresses in `Deploy.s.sol` are correct

### Smart Contracts

1. Set environment variable: `export PRIVATE_KEY=your_private_key`
2. Run: `forge script script/Deploy.s.sol --rpc-url bsc --broadcast`
3. Record the deployed addresses from console output

### Post-Deployment Steps

1. **Fund the vault**: Transfer USDT to the DonationMatchVault address
2. **Approve tranche**: Vault owner calls `vault.approveUsdt(trancheAddress, amount)`
3. **Start first tranche**: Admin calls `tranche.startFirstTranche()` via AccessManager
4. **Update frontend**: Set contract addresses in `frontend/.env`
5. **Deploy frontend**: Push to trigger Render deployment

### Frontend

1. Copy `.env.example` to `.env`
2. Set `VITE_DONATION_TRANCHE_ADDRESS` and `VITE_DONATION_VAULT_ADDRESS`
3. Deploy to Render (configured via `render.yaml`)

## License

AGPL-3.0 - All funded development is open source.
