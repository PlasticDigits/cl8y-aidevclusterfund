# Sprint 1 Handoff Document

## Summary

Sprint 1 established the foundation for the CL8Y Fund platform - a private, invite-only fundraiser for AI dev cluster infrastructure. The core smart contracts and frontend scaffold are complete and functional.

---

## What Went Right

### Smart Contracts
- **Clean Architecture**: Followed patterns from `cl8y-token-sc` - AccessManaged for role-based access, SafeERC20 for token transfers
- **Comprehensive Testing**: 25 tests covering deposits, matching, repayments, tranche lifecycle, and edge cases - all passing
- **Correct APR Logic**: Non-compounding per-second interest calculation works correctly
- **Note Completion**: Notes are preserved as historical records when fully repaid (not destroyed)

### Frontend
- **Design System Alignment**: Successfully adopted CL8Y-web's dark theme with gold accents
- **Wagmi Integration**: Wallet connection, contract reads, and write flows are wired up
- **Access Gate**: Simple but effective invite code mechanism
- **Build Success**: TypeScript compiles cleanly, Vite builds without errors

### Documentation
- **PROPOSAL.md**: Comprehensive high-level design document
- **README.md**: Clear setup and deployment instructions

---

## What Went Wrong

### Technical Debt

1. **No ERC721Enumerable**: The `DonationTranche` contract uses basic ERC721, not ERC721Enumerable. This means:
   - Cannot enumerate a user's tokens on-chain
   - Must rely on event indexing to list user's notes
   - Added complexity for frontend note display

2. **Manual Type Casting**: Had to cast contract return types in `App.tsx`:
   ```typescript
   type TrancheResult = readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean];
   const trancheResult = trancheData as TrancheResult | undefined;
   ```
   Should generate proper types from ABI.

3. **Interest Reset Edge Case**: When principal is repaid, the timestamp resets to `block.timestamp`. This means any interest accrued between the last payment and the current block is "locked in" via `interestPaid`, but the UX could be confusing.

### Missing Features

4. **MyNotes Incomplete**: The component shows note count but cannot display individual notes or their details. Commented as "enumeration coming soon."

5. **Past Tranches Not Displayed**: Frontend only shows current tranche. Historical tranches need manual iteration.

6. **No Loading/Error States**: Minimal feedback for pending transactions or failures.

---

## Gaps Remaining

| Gap | Description | Effort |
|-----|-------------|--------|
| Update README | Add deployment instructions, links to other docs to README.md | 1 hours |
| Note Enumeration | Add ERC721Enumerable or use events to list user notes | 4 hours |
| Past Tranches View | Display completed tranches with stats | 2 hours |
| Transaction Feedback | Toast notifications for success/failure | 2 hours |
| Mobile Testing | Verify responsive design on actual devices | 2 hours |
| Note Transfer UI | Allow users to transfer notes to other addresses | 2 hours |
| Token URI | Add on-chain or off-chain metadata for NFTs | 4 hours |
| Admin Dashboard | UI for scheduling tranches, setting APR | 6 hours |

---

## File Overview

### Smart Contracts (`/smartcontracts`)

```
src/
├── DonationTranche.sol    # Main contract (430 lines)
│   ├── ERC721 NFT minting
│   ├── Tranche management (2-week cycles)
│   ├── Deposit with 1:1 vault matching
│   ├── Repayment (interest first, then principal)
│   └── Note completion tracking
│
└── DonationMatchVault.sol # Vault contract (82 lines)
    ├── Holds USDT for matching
    ├── Receives matched NFTs
    └── Owner withdrawal

test/
└── DonationTranche.t.sol  # 25 tests (490 lines)

script/
└── Deploy.s.sol           # Deployment script
```

### Frontend (`/frontend`)

```
src/
├── components/
│   ├── AccessGate.tsx     # Invite code gate
│   └── ui/                # Button, Card, ProgressBar
│
├── features/
│   ├── Hero.tsx           # Landing hero section
│   ├── TrancheCard.tsx    # Current tranche display
│   ├── FundingTimeline.tsx # dApp milestone visualization
│   ├── DepositModal.tsx   # USDT deposit flow
│   ├── MyNotes.tsx        # User's donation notes (incomplete)
│   └── WalletConnect.tsx  # Wallet connection
│
├── hooks/
│   └── useAccessCode.ts   # Access code state
│
├── lib/
│   ├── config.ts          # Addresses, constants, milestones
│   └── abi/               # Contract ABIs
│
└── providers/
    └── WagmiProvider.tsx  # Wagmi + React Query setup
```

---

## Testing Commands

```bash
# Smart Contracts
cd smartcontracts
forge test -vv                    # Run all tests
forge test --match-test Deposit   # Run specific tests
forge coverage                    # Coverage report

# Frontend
cd frontend
npm run dev                       # Development server
npm run build                     # Production build
npm run preview                   # Preview production build
```

---

## Deployment Checklist

### Pre-Deployment
- [ ] Review contract code
- [ ] Verify all tests pass
- [ ] Confirm addresses in `Deploy.s.sol`

### Deployment
- [ ] Set `PRIVATE_KEY` environment variable
- [ ] Run: `forge script script/Deploy.s.sol --rpc-url bsc --broadcast`
- [ ] Record deployed addresses

### Post-Deployment
- [ ] Vault owner: Fund vault with USDT
- [ ] Vault owner: Call `vault.approveUsdt(trancheAddress, amount)`
- [ ] Admin (via AccessManager): Call `tranche.startFirstTranche()`
- [ ] Update `frontend/.env` with contract addresses
- [ ] Deploy frontend to Render

---

## Known Issues

1. **Matching Requires Pre-Approval**: The vault must approve the tranche contract before any matching works. If forgotten, deposits succeed but without matching. 
FIX: Constructor for vault should consume the tranche address using precomputed address.

2. **No Graceful Degradation**: If contract addresses aren't set, frontend shows demo data. This is intentional for preview but should be more explicit.
FIX: Add alert bar at top, "SHOWING DEMO DATA ONLY"

3. **USDT Decimals Assumption**: Code assumes USDT has 18 decimals (standard on BSC). If using a different token, adjust accordingly.
FIX: Double check RPC for BSC USDT decimals and document

4. **Rate Limiting**: No rate limiting on deposits. A user could fill an entire tranche in one transaction.
FIX: None required, filling tranche is allowed. Document.

---

## Recommendations for Sprint 2

1. **Priority 1**: Improve documentation linking, discoverability, and deployment instructions.
2. **Priority 2**: Implement note enumeration (consider ERC721Enumerable upgrade or event-based approach)
3. **Priority 3**: Add past tranches display
4. **Priority 4**: Improve transaction feedback (toasts, loading states)
5. **Priority 5**: Fix Known Issues


---

## Contact Points

- **AccessManager**: `0x5823a01A5372B779cB091e47DBBb176F2831b4c7`
- **Cluster Manager**: `0x30789c78b7640947db349e319991aaec416eeb93`
- **Vault Owner (Multisig)**: `0x745A676C5c472b50B50e18D4b59e9AeEEc597046`
- **USDT (BSC)**: `0x55d398326f99059fF775485246999027B3197955`

---

*Sprint 1 completed. Ready for deployment and iteration.*
