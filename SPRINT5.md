# Sprint 5 Handoff Document

## Summary

Sprint 4 completed all core smart contract work and added key frontend features. Sprint 5 focuses on **frontend polish** and **comprehensive E2E testing** to ensure production readiness.

---

## What Went Right in Sprint 4

### Smart Contract Improvements
- **Partial Matching**: Vault now partially matches deposits when funds are limited (was all-or-nothing)
- **Tranche Existence Check**: `collectTranche()` now reverts for non-existent tranches with `TrancheNonexistant` error
- **Interest Tracking Fix**: Added `interestAccrued` field to correctly track interest across principal reductions
- **114 Tests Passing**: Comprehensive test coverage including 39 adversarial tests

### Frontend Features Added
- **RepayModal**: Full repayment flow with USDT approval handling
- **PortfolioSummary**: Aggregate statistics for user's donation notes
- **VaultDashboard**: Admin UI for vault operations (withdraw, approve)
- **E2E Test Suite**: 25+ Playwright tests covering major user flows

---

## What Went Wrong / Known Issues

### 1. Interest Display Discrepancy
The frontend shows `interestPerSecond` which is calculated on current remaining principal. However, `interestOwed` includes locked-in `interestAccrued` from before principal reductions. Users might be confused when `interestOwed ≠ interestPerSecond × elapsed`.

**Recommendation**: Add tooltip explaining interest calculation, or display `interestAccrued` separately in the UI.

### 2. Repay Function Forces Interest-First
The `repay()` function always pays ALL accrued interest before any principal. Users cannot choose to pay principal only. This is by design but not documented in the UI.

**Recommendation**: Add UI text explaining "Interest is paid first, then principal."

### 3. Dust Threshold Behavior (Verified - No Interest Loss)
Notes are marked `fullyRepaid` when `remainingPrincipal < 1 USDT`. The contract correctly ensures **all interest is paid before any principal reduction**, so no interest is lost.

**How it works**: To reduce principal below dust threshold, you must pay `interestOwed + (principal - dust)`. The repay function pays all interest first, then reduces principal. When the note is marked complete, `interestOwed = 0`.

**What IS lost**: The dust principal (< 1 USDT) is forgiven - the note owner doesn't receive it. This is intentional to prevent micro-repayment griefing.

**Tests added**: `test_NoInterestLostOnDustThresholdCompletion` and `test_CannotReducePrincipalWithoutPayingAllInterest` verify this behavior.

### 4. E2E Tests Not Fully Verified
The Playwright tests were written but not run against the actual devnet due to environment setup. They may have selector issues or timing problems.

**Priority**: Run and fix E2E tests before production, using the scripts/devnet-*.sh files.

---

## Sprint 5 Scope

| Feature | Description | Effort |
|---------|-------------|--------|
| E2E Test Verification | Run and fix all Playwright tests against devnet | 4 hours |
| Interest Display Improvement | Show `interestAccrued` in UI, add explanatory text | 2 hours |
| Loading States | Add loading spinners/skeletons for async data | 2 hours |
| Mobile Responsiveness | Test and fix mobile layout issues | 3 hours |
| Error Messages | Improve user-facing error messages for failed txs | 2 hours |
| Repay Flow Polish | Add interest-first explanation, amount suggestions | 2 hours |
| Frontend Tests | Add Vitest unit tests for key components | 4 hours |
| Performance Optimization | Code splitting, lazy loading for large bundles | 3 hours |

---

## Implementation Details

### 1. E2E Test Verification

**Priority: HIGH**

The E2E tests exist but need to be run and debugged.

**Steps:**
```bash
# 1. Start devnet
./scripts/devnet-start.sh

# 2. Run tests
cd frontend && npx playwright test

# 3. Fix failing tests
npx playwright test --headed --debug

# 4. Stop devnet
./scripts/devnet-stop.sh
```

**Known potential issues:**
- Selectors may not match actual UI elements
- Timing issues with transaction confirmations
- Modal close behavior may differ

**File:** `frontend/e2e/deposit.spec.ts`

---

### 2. Interest Display Improvement

Show users the full picture of their interest calculation.

**Files to modify:**
- `frontend/src/features/MyNotes.tsx`
- `frontend/src/features/RepayModal.tsx`

**Changes:**
1. Display `interestAccrued` in note details (already in data, just not shown)
2. Add tooltip: "Interest Owed = Accrued Interest + Current Period Interest - Already Paid"
3. In RepayModal, show breakdown:
   - Interest owed: X USDT
   - Remaining principal: Y USDT
   - Your payment: Z USDT → Pays W interest, V principal

**Example UI:**
```tsx
<div className="text-sm text-gray-500">
  Interest owed: {formatUnits(interestOwed, 18)} USDT
  <InfoTooltip>
    Includes {formatUnits(interestAccrued, 18)} USDT locked in from previous periods
  </InfoTooltip>
</div>
```

---

### 3. Loading States

Add loading indicators to prevent "flash of empty content."

**Files to modify:**
- `frontend/src/features/MyNotes.tsx`
- `frontend/src/features/PortfolioSummary.tsx`
- `frontend/src/features/TrancheCard.tsx`
- `frontend/src/features/VaultDashboard.tsx`

**Pattern:**
```tsx
if (isLoading) {
  return (
    <div className="animate-pulse">
      <div className="h-4 bg-gray-700 rounded w-3/4 mb-2" />
      <div className="h-4 bg-gray-700 rounded w-1/2" />
    </div>
  );
}
```

---

### 4. Mobile Responsiveness

Test on mobile viewports and fix layout issues.

**Key areas to check:**
- TrancheCard on narrow screens
- Note cards in MyNotes
- Admin Dashboard (may need accordion on mobile)
- Modal sizing and scrolling

**Testing:**
```bash
# Playwright mobile test
npx playwright test --project=mobile
```

**Add to playwright.config.ts:**
```typescript
projects: [
  { name: 'desktop', use: { viewport: { width: 1280, height: 720 } } },
  { name: 'mobile', use: { viewport: { width: 375, height: 667 } } },
],
```

---

### 5. Error Messages

Improve error handling for failed transactions.

**Current state:** Toast shows generic error or raw error message.

**Improvements:**
- Parse common revert reasons into user-friendly messages
- Show actionable guidance

**Example mapping:**
```typescript
const errorMessages: Record<string, string> = {
  'BelowMinimumDeposit': 'Deposit must be at least 100 USDT',
  'TrancheNotActive': 'No active tranche. Check back later.',
  'TrancheFull': 'This tranche is full. Wait for the next one.',
  'NoteFullyRepaid': 'This note has already been fully repaid.',
  'ZeroAmount': 'Amount must be greater than 0.',
  'ERC20InsufficientAllowance': 'Please approve USDT first.',
};
```

**File:** Create `frontend/src/lib/errorMessages.ts`

---

### 6. Repay Flow Polish

Improve the repay experience.

**Changes to RepayModal:**
1. Add "Pay Interest Only" and "Pay Full Balance" quick buttons
2. Show clear breakdown of where payment goes
3. Add text: "Interest is always paid before principal"

**Example:**
```tsx
<div className="space-y-2">
  <button onClick={() => setAmount(interestOwed)}>
    Pay Interest Only ({formatUnits(interestOwed, 18)} USDT)
  </button>
  <button onClick={() => setAmount(interestOwed + remainingPrincipal)}>
    Pay Full Balance ({formatUnits(interestOwed + remainingPrincipal, 18)} USDT)
  </button>
</div>
```

---

### 7. Frontend Unit Tests

Add Vitest tests for key components.

**Setup:**
```bash
cd frontend
npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom
```

**Files to create:**
- `frontend/src/features/__tests__/MyNotes.test.tsx`
- `frontend/src/features/__tests__/PortfolioSummary.test.tsx`
- `frontend/src/features/__tests__/TrancheCard.test.tsx`

**Example test:**
```typescript
import { render, screen } from '@testing-library/react';
import { PortfolioSummary } from '../PortfolioSummary';

test('shows zero state when no notes', () => {
  render(<PortfolioSummary />);
  expect(screen.queryByText('Portfolio Summary')).not.toBeInTheDocument();
});
```

---

### 8. Performance Optimization

The current bundle is 535 KB (161 KB gzipped). Consider splitting.

**Options:**
1. Lazy load admin components:
```tsx
const AdminDashboard = lazy(() => import('./AdminDashboard'));
const VaultDashboard = lazy(() => import('./VaultDashboard'));
```

2. Split wagmi/viem chunks:
```typescript
// vite.config.ts
build: {
  rollupOptions: {
    output: {
      manualChunks: {
        'wagmi': ['wagmi', '@wagmi/core'],
        'viem': ['viem'],
      }
    }
  }
}
```

---

## File Changes Summary

| File | Action | Priority |
|------|--------|----------|
| `frontend/e2e/deposit.spec.ts` | Debug/fix | P0 |
| `frontend/playwright.config.ts` | Add mobile project | P1 |
| `frontend/src/features/MyNotes.tsx` | Add loading state, interest tooltip | P1 |
| `frontend/src/features/RepayModal.tsx` | Add quick buttons, explanation | P1 |
| `frontend/src/features/PortfolioSummary.tsx` | Add loading state | P1 |
| `frontend/src/lib/errorMessages.ts` | Create | P2 |
| `frontend/src/features/__tests__/*.test.tsx` | Create | P2 |
| `frontend/vite.config.ts` | Add manual chunks | P3 |

---

## Testing Commands

```bash
# Smart Contracts
cd smartcontracts
forge test -vv                                    # All 114 tests
forge test --match-path test/*.adversarial.t.sol  # 39 adversarial tests

# Frontend
cd frontend
npm run dev                                       # Dev server
npm run build                                     # Production build
npm run test:e2e                                  # E2E tests (requires devnet)

# E2E with debug
cd frontend
npx playwright test --headed                      # Watch mode
npx playwright test --debug                       # Step through

# Devnet
./scripts/devnet-start.sh                         # Start
./scripts/devnet-status.sh                        # Check status
./scripts/devnet-stop.sh                          # Stop (ALWAYS run after testing)
```

---

## Current Contract State

### DonationTranche.sol
- **Note struct** now has 9 fields (added `interestAccrued`)
- **getNoteInfo()** returns 14 values (added `interestAccrued` at position 10)
- **Partial matching**: Vault contributes what it can, not all-or-nothing
- **Tranche validation**: `collectTranche()` reverts for non-existent tranches

### Key ABI Change
The `getNoteInfo` function now returns:
```
owner, trancheId, aprBps, timestamp, interestOwed, interestPerSecond,
principal, principalRepaid, interestPaid, interestAccrued,  // <-- NEW
remainingPrincipal, totalRepaid, fullyRepaid, completedTimestamp
```

Frontend has been updated to handle this.

---

## Architecture Notes

### Interest Calculation
```
interestOwed = interestAccrued + currentPeriodInterest - interestPaid

Where:
- interestAccrued = sum of interest locked in at each principal reduction
- currentPeriodInterest = remainingPrincipal × aprBps × elapsed / (10000 × 365 days)
- interestPaid = cumulative interest already paid
```

### Repay Flow
1. Calculate `interestOwed`
2. If `amount <= interestOwed`: all goes to interest
3. If `amount > interestOwed`: pay all interest, rest to principal
4. If principal reduced: lock in current period interest to `interestAccrued`, reset timestamp

---

## Sprint 4 Metrics

| Metric | Value |
|--------|-------|
| Smart Contract Tests | 114 passing (39 adversarial) |
| Frontend Build Size | 535 KB (161 KB gzipped) |
| New Contract Fields | 1 (interestAccrued) |
| E2E Test Cases | 25+ |
| Features Completed | 6 (Repay UI, Portfolio, Vault UI, Adversarial Tests, Partial Matching, Interest Fix) |

---

## Pre-Sprint 5 Checklist

- [ ] Run E2E tests and document failures
- [ ] Verify devnet scripts still work
- [ ] Check frontend builds without errors
- [ ] Review mobile layout in browser dev tools
- [ ] Test repay flow end-to-end manually

---

*Sprint 4 completed. Ready for frontend polish, E2E verification, and production hardening.*
