# CL8Y Donation Tranche Smart Contracts

Smart contracts for the CL8Y donation matching platform built with Foundry.

## Architecture

### Contracts

| Contract | Proxy | Description |
|----------|-------|-------------|
| `DonationTranche` | UUPS (ERC-1967) | ERC721 NFT for donation notes with tranches, matching, and repayments |
| `DonationMatchVault` | None | Simple vault holding USDT for matching deposits |

### Why UUPS Proxy for DonationTranche?

The `DonationTranche` contract uses the **UUPS (Universal Upgradeable Proxy Standard)** pattern because:

1. **Complex Logic** - 700+ lines handling tranches, matching, repayments, and APR calculations. High likelihood of needing bug fixes or feature additions post-launch.

2. **Valuable NFT State** - Once users hold donation notes with principal and accrued interest, migration to a new contract would be disruptive. Proxy upgrades preserve all token ownership and state.

3. **Minimal Gas Overhead** - UUPS adds ~200 gas per call (delegatecall cost), negligible compared to the operations performed.

4. **AccessManager Integration** - Upgrade authorization uses the existing `AccessManaged` pattern via `_authorizeUpgrade()`.

### Why No Proxy for DonationMatchVault?

- Only 82 lines, trivially simple
- `DonationTranche.setVault()` already allows pointing to a new vault
- No per-user state to preserve

## Upgrade Process

### Prerequisites

- Caller must have admin role in AccessManager
- New implementation must maintain storage layout compatibility

### Steps

1. **Deploy new implementation**:
   ```bash
   forge script script/Upgrade.s.sol:UpgradeScript --rpc-url $RPC_URL --broadcast
   ```

2. **Upgrade proxy** (via AccessManager):
   ```solidity
   // From account with ADMIN_ROLE
   donationTranche.upgradeToAndCall(newImplementation, "");
   ```

### Storage Layout Rules

When upgrading, you MUST follow these rules to avoid storage corruption:

1. **Never remove or reorder existing state variables**
2. **Only append new variables at the end**
3. **Never change the type of existing variables**
4. **Use storage gaps for future-proofing** (already included)

Example of safe addition:
```solidity
// ============ State Variables ============
// ... existing variables ...
uint256 public newVariable;  // ✅ Safe: appended at end

// ============ Storage Gap ============
uint256[48] private __gap;   // Reduced from 49 to 48
```

## Development

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Format

```bash
forge fmt
```

### Local Deployment (Anvil)

```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy
forge script script/DeployLocal.s.sol:DeployLocalScript --rpc-url http://localhost:8545 --broadcast
```

### Mainnet Deployment (BSC)

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $BSC_RPC_URL --broadcast --verify
```

## Contract Addresses

### BSC Mainnet
- DonationTranche (Proxy): `0x3083916479BAf9B930983427993E788fB0b572AD`
- DonationTranche (Implementation): `T0xe6bfC1bA1455EACb7Ccd70c5c3e7A577d0e535EDBD`
- DonationMatchVault: `0x83110920D07E124B905EeAfc0f6Df3349Fdd77f5`
- AccessManager: `0x5823a01A5372B779cB091e47DBBb176F2831b4c7`

### Local (Anvil)
Addresses are logged during deployment. See `scripts/.devnet-status.json` when using devnet scripts.

## Post-Deployment Checklist

1. Fund the vault with USDT for matching
2. Vault owner approves tranche for unlimited USDT spending
3. Admin calls `startFirstTranche()` via AccessManager
4. Update frontend `.env` with deployed addresses

## Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - ERC721, AccessManaged, SafeERC20
- [OpenZeppelin Contracts Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) - UUPS, Initializable
- [Forge Std](https://github.com/foundry-rs/forge-std) - Testing utilities

## License

AGPL-3.0
