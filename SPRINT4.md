# Sprint 3 Handoff Document

## Summary

Sprint 3 focused on building devnet testing infrastructure and adding key UI features. Major accomplishments include local Anvil deployment scripts with status tracking, auto-connecting test wallet, note transfer UI, error boundaries, and admin dashboard.

---

## What Went Right

### Devnet Infrastructure
- **Start/Stop/Status Scripts**: Clean bash scripts with `.devnet-status.json` for state tracking
- **AccessManager Integration**: Proper role grants for admin functions in local deployment
- **Auto-Connect Wallet**: Mock connector with Anvil's test account works seamlessly

### Frontend Features
- **Admin Dashboard**: Four admin functions (startFirstTranche, scheduleAdditionalTranches, setVault, setDefaultApr)
- **Note Transfer UI**: TransferModal component with address validation and toast feedback
- **Error Boundaries**: Graceful error handling wrapping key components

### Testing
- **Full E2E Manual Test**: Deposit flow verified in browser - approval, deposit, matching, NFT mint all work
- **26 Smart Contract Tests**: All passing

---

## What Went Wrong

1. **AccessManaged Misunderstanding**: Initially tried using EOA as authority for DonationTranche. Required deploying actual AccessManager with role grants.

2. **MyNotes Load Delay**: Brief "0 notes" flash before data loads after page refresh. Could use loading state.

3. **No Automated E2E Tests**: Manual browser testing only - no Playwright/Cypress suite.

---

## Sprint 4 Scope

| Feature | Description | Effort |
|---------|-------------|--------|
| Repayment UI | Users can repay notes from frontend | 4 hours |
| Portfolio Summary | Total value, interest earned, etc. | 2 hours |
| Admin UI | Start next tranche | 2 hours |
| Adversarial Smart Contract Tests | Red-team testing for security | 6 hours |
| Vault Operations UI | UI for vault owner functions | 3 hours |
| E2E Test Automation | Playwright tests using devnet | 6 hours |

---

## Implementation Details

### 1. Repayment UI

Allow any user to repay donation notes from the frontend.

**File:** `frontend/src/features/RepayModal.tsx` (new)

**Functionality:**
- Input: Note ID (tokenId) to repay
- Input: Amount to repay (USDT)
- Display: Current interest owed, remaining principal
- Button: "Repay" that calls `tranche.repay(tokenId, amount)`
- Note: Anyone can repay any note - payment goes to current owner

**Contract function:**
```solidity
function repay(uint256 tokenId, uint256 amount) external
```

**UI Location:** 
- Standalone "Repay a Note" section
- Admin vault page
**Key consideration:** The repayer doesn't need to own the note. Show note owner address so repayer knows where funds go.

---

### 2. Portfolio Summary

Aggregate statistics for connected wallet's notes.

**File:** `frontend/src/features/PortfolioSummary.tsx` (new)

**Metrics to display:**
- Total notes owned
- Total principal invested
- Total interest earned (across all notes)
- Total principal repaid
- Current value (remaining principal + interest owed)
- Average APR (if notes have different APRs)

**Data source:** Aggregate from `getNoteInfo()` for all owned tokens using `tokenOfOwnerByIndex`.

**UI Location:** Top of MyNotes section or separate card.

---

### 3. Adversarial Smart Contract Tests

Add red-team tests to `smartcontracts/test/`. Use fuzzing where useful.

**New test file:** `smartcontracts/test/DonationTranche.adversarial.t.sol`

**Test categories:**

#### Reentrancy Tests
```solidity
function test_ReentrancyOnDeposit() public
function test_ReentrancyOnRepay() public
function test_ReentrancyOnCollect() public
```

#### Access Control Tests
```solidity
function test_NonAdminCannotStartTranche() public
function test_NonAdminCannotScheduleTranches() public
function test_NonAdminCannotSetVault() public
function test_NonAdminCannotSetApr() public
function test_NonOwnerCannotWithdrawVault() public
```

#### Economic Attack Tests
```solidity
function test_CannotFillTrancheWithFlashLoan() public  // If applicable
function test_DustDepositRejected() public
function test_CannotDepositAfterTrancheEnds() public
function test_CannotDoubleCollect() public
```

#### Edge Case Tests
```solidity
function test_ZeroAmountRepayReverts() public
function test_RepayMoreThanOwedCapsAtTotal() public
function test_InterestCalculationAtMaxTime() public
function test_MaxUint256AprDoesNotOverflow() public
function test_TransferDuringRepayment() public
```

#### Vault Griefing Tests
```solidity
function test_VaultCanRevokeApprovalMidDeposit() public
function test_EmptyVaultMatchingGraceful() public
```

Additionally, red team the tranche logic as its quite complex. Make sure it cant be put into an invalid state where the next tranche wont start.

---

### 4. Vault Operations UI

UI for vault owner (CZodiac multisig) to manage the vault.

**File:** `frontend/src/features/VaultDashboard.tsx` (new)

**Functionality:**
- Display vault USDT balance
- Display notes owned by vault
- Withdraw button (calls `vault.withdraw()`)
- Approve tranche button (calls `vault.approveUsdt()`)
- Repay notes

**Access control:** Only show to connected wallet that matches `vault.owner()`.

**Note:** In production, this is a multisig - they'd use Gnosis Safe UI. This is primarily for testing and visibility.

---

### 5. E2E Test Automation

Automated browser tests using devnet infrastructure.

## File Changes Summary

| File | Action |
|------|--------|
| `frontend/src/features/RepayModal.tsx` | Create - Repayment UI |
| `frontend/src/features/MyNotes.tsx` | Modify - Add transfer |
| `frontend/src/features/PortfolioSummary.tsx` | Create - Aggregate stats |
| `smartcontracts/test/DonationTranche.adversarial.t.sol` | Create - Security tests |
| `frontend/src/features/VaultDashboard.tsx` | Create - Vault operations |
| `frontend/e2e/deposit.spec.ts` | Create - E2E tests |
| `frontend/playwright.config.ts` | Create - Playwright config |

---

## Testing Commands

```bash
# Smart Contracts
cd smartcontracts
forge test -vv                                    # All tests
forge test --match-path test/*.adversarial.t.sol  # Adversarial only

# Frontend
cd frontend
npm run dev                                       # Dev server
npm run build                                     # Production build

# E2E Tests
./scripts/devnet-start.sh                         # Start devnet first
cd frontend && npx playwright test                # Run E2E
./scripts/devnet-stop.sh                          # Stop devnet after

# Devnet
./scripts/devnet-start.sh                         # Start
./scripts/devnet-status.sh                        # Check status
./scripts/devnet-stop.sh                          # Stop (ALWAYS run after testing)
```

---

## Key Addresses (Anvil Local Testing)

| Role | Address | Private Key |
|------|---------|-------------|
| Deployer/Admin | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec...` |
| Test User 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e9...` |
| Test User 2 | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111af...` |

---

## Current User Story Coverage

| User Story | Sprint 3 | Sprint 4 Target |
|------------|----------|-----------------|
| Deposit USDT | Done | - |
| Receive NFT note | Done | - |
| View interest owed | Done | - |
| Receive repayments | Contract only | **Add UI** |
| Transfer notes | Done | - |
| Vault auto-match | Done | - |
| Vault withdraw | Contract only | **Add UI** |
| Collect tranches | Contract only | - |
| Repay notes | Contract only | **Add UI** |

---

## Cursor Rules

A cursor rule exists at `.cursor/rules/devnet-workflow.mdc` explaining:
- How to use start/stop/status scripts
- Always call `./scripts/devnet-stop.sh` after testing
- Test account details

---

## Sprint 3 Metrics

| Metric | Value |
|--------|-------|
| Smart Contract Tests | 31 passing |
| New Files Created | 15 |
| Frontend Build Size | 522 KB gzipped |
| Features Added | 5 (devnet, transfer, error boundaries, admin, test wallet) |

---

## Pre-Sprint 4 Fix: startNextTranche

Before starting Sprint 4, a bug was identified and fixed:

**Problem:** When all scheduled tranches were exhausted and collected, there was no way to restart fundraising even after calling `scheduleAdditionalTranches()`. The `startFirstTranche()` function could only be called once.

**Solution:** Added `startNextTranche()` function to resume tranches after a gap:
- Requires first tranche already started
- Requires current tranche ended and collected
- Requires scheduled tranches > 0

**Files changed:**
- `smartcontracts/src/DonationTranche.sol` - Added `startNextTranche()` and 3 new error types
- `smartcontracts/test/DonationTranche.t.sol` - Added 5 new tests (regression + edge cases)

---

*Sprint 3 completed. Ready for repayment UI, marketplace, portfolio summary, adversarial tests, vault UI, E2E automation, and admin dashboard update.*
