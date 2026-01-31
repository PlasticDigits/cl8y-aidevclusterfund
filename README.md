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

### Deployed Contracts (BSC Mainnet)

| Contract | Address | Notes |
|----------|---------|-------|
| **DonationTranche (Proxy)** | `0x3083916479BAf9B930983427993E788fB0b572AD` | Main contract for deposits/repayments |
| **DonationTranche (Implementation)** | `0xe6bfC1bA1455EACb7Ccd70c5c3e7A577d0e535ED` | UUPS upgradeable implementation |
| **DonationMatchVault** | `0x83110920D07E124B905EeAfc0f6Df3349Fdd77f5` | Holds USDT for matching |

### External Addresses (BSC)

| Contract/Address | Address | Notes |
|------------------|---------|-------|
| AccessManager | `0x5823a01A5372B779cB091e47DBBb176F2831b4c7` | Role-based access control |
| USDT | `0x55d398326f99059fF775485246999027B3197955` | BSC USDT (18 decimals) |
| Cluster Manager | `0x30789c78b7640947db349e319991aaeC416eeB93` | Receives collected tranche funds |
| Vault Owner | `0x745A676C5c472b50B50e18D4b59e9AeEEc597046` | CZodiac multisig |
| Deployer | `0x1e8c3c005ef1374e422cd659c46d427f6b9f5b8f` | Deployment wallet |

### Deployment Configuration

| Parameter | Value |
|-----------|-------|
| First Tranche Start | `1769945400` (Sat Jul 01 2026 22:30:00 UTC) |
| Default APR | 30% (3000 bps) |
| Tranche Duration | 2 weeks |
| Initial Tranche Cap | 1,584 USDT |
| Vault Approval | 17,500 USDT |

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

Deploy using interactive wallet flow (private key prompted at runtime):

```bash
cd smartcontracts
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://bsc-dataseed.binance.org/ \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --sender <DEPLOYER_ADDRESS> \
  --interactives 1 \
  --chain-id 56 \
  -vvvv
```

Record the deployed addresses from console output.

### Post-Deployment Steps

1. **Configure roles**: Use Gnosis Safe Transaction Builder to set function roles on AccessManager
2. **Fund the vault**: Transfer USDT to the DonationMatchVault address for matching
3. **Update frontend**: Set contract addresses in `frontend/.env`
4. **Deploy frontend**: Push to trigger Render deployment

Note: First tranche is configured at deployment (starts at specified epoch). Vault is pre-approved for 17,500 USDT.

### Frontend

1. Copy `.env.example` to `.env`
2. Set `VITE_DONATION_TRANCHE_ADDRESS` and `VITE_DONATION_VAULT_ADDRESS`
3. Deploy to Render (configured via `render.yaml`)

## License

AGPL-3.0 - All funded development is open source.
