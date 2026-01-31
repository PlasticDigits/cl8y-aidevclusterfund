# CL8Y Fund: AI Dev Cluster Infrastructure Fundraiser

**Domain**: fund.cl8y.com  
**Status**: Proposal  
**Version**: 1.0

---

## Executive Summary

CL8Y Fund is a private, invite-only fundraising platform enabling the CL8Y community to contribute USDT toward AI inference infrastructure costs. Contributors receive NFT "Donation Notes" with 30% APR rewards, matched 1:1 by the CZodiac vault, plus 1.5x matching in QA/Audit consulting services from Ceramic (the AI dev cluster manager). All funded development produces AGPL open-source software for public research and education.

---

## Purpose and Ideology

### Mission

Democratize access to AI-powered blockchain development by crowdfunding inference costs for open-source tooling that benefits the entire blockchain ecosystem.

### Core Principles

**Transparency**  
All smart contracts are public and auditable. The blockchain serves as an immutable record of contributions, matching, and repayments. Only the frontend carries access restrictions—not for security, but to signal the private nature of the fundraise.

**Open Source Commitment**  
Every dollar raised funds development of AGPL-licensed software. This ensures that all blockchain users benefit from the infrastructure, not just contributors. The CL8Y community builds for everyone.

**Community First**  
The private invite system ensures genuine supporters participate, not speculators or opportunists. This is a community-driven initiative where contributors understand and believe in the mission.

**Fair Rewards**  
Contributors deserve compensation for supporting infrastructure that benefits everyone. The 30% APR acknowledges that early supporters take on risk and should be rewarded accordingly.

**Matched Contributions**  
The CZodiac vault matches every community dollar 1:1, doubling the impact. Additionally, Ceramic provides 1.5x matching in QA and audit services, further amplifying each contribution's value.

### Value Proposition

For every 1 USDT contributed by the community:

- 1 USDT matched by CZodiac vault (2 USDT total capital)
- 1.5 USDT equivalent in QA/Audit consulting services from Ceramic
- 30% APR rewards on the contributor's principal

This creates a 3.5x multiplier effect on community contributions when accounting for services.

---

## User Stories

### The Community Contributor

> "As a CL8Y community member, I want to support AI dev infrastructure and receive fair compensation through transparent, on-chain donation notes that track my contribution and accrued rewards. I should be able to see exactly how much I've contributed, how much interest I've earned, and track repayments as they happen."

**Acceptance Criteria**:
- Can deposit USDT during active tranches
- Receives NFT donation note with immutable terms
- Can view current interest owed at any time
- Receives USDT when repayments are made
- Can transfer donation notes to other addresses

### The Vault Operator

> "As the CZodiac multisig, I want to match community donations automatically when funds are available, withdraw excess funds when needed for other ecosystem purposes, and hold donation notes that represent our matched contributions."

**Acceptance Criteria**:
- Vault automatically matches deposits when USDT available
- Receives NFT for each matched contribution
- Can withdraw all USDT from vault at any time
- Receives repayment benefits on vault-held notes

### The AI Dev Cluster Manager

> "As Ceramic, I want to collect funded tranches to pay for inference costs on schedule, while the community can track exactly how their contributions are being used through a public funding timeline."

**Acceptance Criteria**:
- Can receive collected tranche funds at designated address
- Tranches auto-progress when collected
- Funding usage is transparent and trackable

### The Repayment Agent

> "As anyone in the ecosystem, I want to repay donation notes to reward contributors and demonstrate the sustainability of the funded projects. Whether I'm the protocol treasury, a grateful user, or the cluster manager returning profits, I should be able to repay any note."

**Acceptance Criteria**:
- Can repay any note by token ID
- Repayments go to current note holder
- Interest reduced first, then principal
- Can partially or fully repay notes

---

## Design Principles

### Simplicity Over Complexity

The system uses proven patterns: ERC721 for notes, simple structs for tranches, flat APR calculations. No exotic mechanisms that require extensive auditing or create unexpected edge cases.

### Immutability Where It Matters

Once a donation note is minted, its terms are fixed. The APR, initial principal, and timestamp cannot be modified. This gives contributors certainty about their expected returns.

### Permissionless Operations

Key functions like `collectTranche` and `repay` are callable by anyone. This prevents single points of failure and ensures the system continues operating even if specific parties become unavailable.

### Completion Tracking

When a note's remaining principal falls below 1 USDT after repayment, the note is marked as fully repaid rather than destroyed. The NFT remains as a permanent record of the contribution and complete repayment, preserving the historical relationship between contributor and the ecosystem.

### Progressive Disclosure

The frontend reveals complexity gradually. First-time visitors see only the invite gate. Upon entry, they see the mission and current tranche. Deeper exploration reveals past tranches, funding timeline, and personal notes.

---

## Architecture Overview

### System Components

The system consists of two smart contracts deployed on BSC and a static frontend:

**DonationTranche Contract**  
The core contract managing tranches, NFT donation notes, deposits, matching coordination, and repayments. Inherits ERC721 for note management and AccessManaged for administrative functions.

**DonationMatchVault Contract**  
A simple holding vault for matching funds and matched NFT notes. Owned by the CZodiac multisig with single-function withdrawal capability.

**Static Frontend**  
A React application providing the user interface for viewing tranches, making deposits, and tracking donation notes. Deployed to Render as a static site with no backend dependencies.

### Data Flow

1. **Deposit Flow**: User approves USDT, calls deposit on DonationTranche, receives NFT. If vault has matching funds, vault's USDT transfers to tranche and vault receives its own NFT.

2. **Repayment Flow**: Any address calls repay with note ID and USDT amount. Contract calculates interest owed, applies payment to interest first, then principal. USDT transfers directly to current note holder.

3. **Collection Flow**: After tranche end time, anyone calls collectTranche. All deposited USDT transfers to the AI dev cluster manager address. Next scheduled tranche begins immediately.

---

## Smart Contract Design

### DonationTranche

**Purpose**: Manages 2-week fundraising tranches, mints NFT donation notes, coordinates matching, and processes repayments.

**Key Responsibilities**:
- Track tranche lifecycle (scheduled, active, ended, collected)
- Mint ERC721 donation notes with immutable terms
- Coordinate with vault for 1:1 matching
- Calculate real-time interest owed
- Process repayments (interest first, then principal)
- Transfer collected funds to cluster manager
- Mark notes as fully repaid when principal < 1 USDT (preserving historical record)

**Access Control**:
- Uses BSC AccessManager at `0x5823a01A5372B779cB091e47DBBb176F2831b4c7`
- Admin functions: startFirstTranche, scheduleAdditionalTranches, setVault, setDefaultApr

**Tranche Rules**:
- Duration: 2 weeks (fixed)
- Default cap: 1,584 USDT (792 community + 792 matched)
- Minimum deposit: 100 USDT
- Maximum deposit: remaining tranche capacity
- Initial tranches: 6 (must schedule more for continuation)
- First tranche starts on explicit admin call

**Note Rules**:
- APR: 30% default, fixed at mint time
- Interest: Non-compounding, calculated per-second
- Fully repaid: When principal falls below 1 USDT, note is marked complete (not destroyed) with final totals recorded
- Transferable: Standard ERC721 transfer mechanics

### DonationMatchVault

**Purpose**: Holds USDT for matching and accumulates matched donation notes.

**Key Responsibilities**:
- Hold USDT contributed by CZodiac for matching
- Receive matched NFT donation notes
- Allow owner to withdraw all USDT

**Ownership**:
- Owner: CZodiac multisig at `0x745A676C5c472b50B50e18D4b59e9AeEEc597046`
- Single owner pattern (OpenZeppelin Ownable)

**Matching Logic**:
- When user deposits, DonationTranche checks vault USDT balance
- If sufficient, vault transfers matching USDT to tranche
- Vault receives its own NFT donation note
- If insufficient, user deposit proceeds without match

### NFT Donation Note Data Model

Each NFT stores on-chain:

- **tokenId**: Unique sequential identifier
- **tranche**: Which tranche this note belongs to
- **apr**: APR percentage in basis points (fixed at mint)
- **timestamp**: Unix timestamp of note creation
- **principal**: Initial deposit amount in USDT
- **principalRepaid**: Amount of principal already repaid
- **interestPaid**: Total interest already paid out
- **fullyRepaid**: Boolean flag indicating note completion
- **completedTimestamp**: When the note was fully repaid (if applicable)

View function returns computed values:

- **owner**: Current holder address
- **interestOwed**: Accumulated unpaid interest (0 if fully repaid)
- **interestPerSecond**: Current rate based on remaining principal (0 if fully repaid)
- **remainingPrincipal**: principal - principalRepaid
- **remainingInterest**: Total outstanding interest
- **totalRepaid**: Sum of principalRepaid + interestPaid (complete historical record)

---

## Frontend Design

### Access Control

The frontend implements a simple invite gate:

- First visit displays modal: "Enter Private Invite Code"
- User enters text, compared plaintext to "donate"
- On match, localStorage flag set, app unlocks
- Flag persists across sessions
- Not security-focused; purely signals private nature

This approach is intentionally simple. The smart contracts are public and anyone can interact directly. The frontend gate exists only to communicate that this fundraise is for invited community members, not the general public.

### Visual Design

Following CL8Y-web design language:

**Color Palette**:
- Primary: Gold (#D4AF37) for accents and CTAs
- Background: Black (#0C0C0C) and Midnight (#1A1F2B)
- Status: Aqua (#22D3EE) for positive, Magenta (#E11D74) for warnings
- Text: Neutral (#EDEDED)

**Typography**:
- Headlines: Space Grotesk Bold
- Body: Inter Regular/Medium
- Numbers/Data: Roboto Mono

**Visual Elements**:
- Card-based layouts with subtle grain texture
- Gold glow effects for emphasis
- Smooth transitions with Framer Motion
- Respects prefers-reduced-motion

### Page Structure

**Main Dashboard**

The primary view showing:
- Hero section with mission statement
- Active tranche with progress bar and countdown
- Matching display (community, vault, services)
- Deposit interface (when wallet connected)
- Past tranches (collapsed, expandable)
- Upcoming tranches (scheduled)

**Funding Timeline**

A visual journey from 0% to 100% showing:
- Progress bar with current funding level
- Milestone markers for proposed dApps
- Cumulative totals at each milestone
- Clear disclaimer about flexibility

**My Notes** (wallet connected)

Personal dashboard showing:
- List of owned donation notes
- Per-note: principal, interest earned, repayments
- Total portfolio value
- Transfer functionality

### Deposit Flow

1. User connects wallet (MetaMask or WalletConnect)
2. Dashboard shows available capacity in current tranche
3. User inputs USDT amount (validated against min/max)
4. User approves USDT spending (if not already approved)
5. User confirms deposit transaction
6. Success state shows NFT token ID and initial terms
7. Note appears in "My Notes" section

---

## Funding Milestones

The funding timeline displays proposed dApps that will be developed as funds are raised. Each milestone shows cumulative funding required.

| Priority | dApp | AI Cost | QA Cost | Cumulative Total |
|----------|------|---------|---------|------------------|
| 1 | BRIDGE v1: EVM to TerraClassic | $931 | $1,200 | $2,131 |
| 2 | DAO NODES: Treasury + Governance | $588 | $1,200 | $3,919 |
| 3 | DEX: V2+V3, Bot Friendly | $1,127 | $1,800 | $6,846 |
| 4 | PERP DEX: Hybrid Architecture | $2,254 | $3,000 | $12,100 |
| 5 | CMM: Auctions & Swaps | $833 | $1,200 | $14,133 |
| 6 | GameFi: Text RPG Platform | $2,695 | $4,200 | $21,028 |
| 7 | Money Market: Oracle-free | $1,078 | $1,800 | $23,906 |

**Important Disclaimer**: These are suggestions only. Some dApps may be dropped or replaced based on community feedback and technical feasibility. All raised funds will be solely used for developing new blockchain technology that is AGPL open source.

---

## Technical Stack

### Smart Contracts

- **Framework**: Foundry/Forge
- **Language**: Solidity ^0.8.30
- **Dependencies**: OpenZeppelin Contracts (latest stable)
- **Network**: BSC Mainnet
- **Testing**: Foundry test suite with fork testing against BSC

### Frontend

- **Framework**: React 19 with Vite 7
- **Styling**: Tailwind CSS
- **Web3**: wagmi v2 + viem v2
- **State Management**: React Query
- **Routing**: React Router DOM
- **Deployment**: Render (static site)

### Project Structure

```
fund/
├── frontend/
│   ├── src/
│   │   ├── app/              # Route pages
│   │   ├── components/       # Reusable UI
│   │   ├── features/         # Feature sections
│   │   ├── hooks/            # Blockchain data hooks
│   │   ├── lib/              # ABIs, utilities
│   │   ├── providers/        # Wagmi, React Query
│   │   └── theme/            # Design tokens
│   ├── public/
│   ├── render.yaml
│   └── package.json
├── smartcontracts/
│   ├── src/
│   │   ├── DonationTranche.sol
│   │   ├── DonationMatchVault.sol
│   │   └── interfaces/
│   ├── script/               # Deployment scripts
│   ├── test/                 # Foundry tests
│   ├── foundry.toml
│   └── remappings.txt
└── PROPOSAL.md
```

---

## Key Addresses

| Entity | Address | Network |
|--------|---------|---------|
| AccessManager | `0x5823a01A5372B779cB091e47DBBb176F2831b4c7` | BSC |
| AI Dev Cluster Manager | `0x30789c78b7640947db349e319991aaec416eeb93` | BSC |
| CZodiac Multisig (Vault Owner) | `0x745A676C5c472b50B50e18D4b59e9AeEEc597046` | BSC |
| USDT | `0x55d398326f99059fF775485246999027B3197955` | BSC |

---

## Economic Model

### Per-Tranche Economics

- **Tranche Duration**: 2 weeks
- **Tranche Cap**: 1,584 USDT total
- **Community Contribution**: Up to 792 USDT
- **Vault Matching**: Up to 792 USDT (1:1)
- **Ceramic Services**: 1.5x of total = 2,376 USD value

### APR Mechanics

- **Rate**: 30% annual
- **Type**: Flat, non-compounding
- **Calculation**: Per-second accrual from mint timestamp
- **Example**: 100 USDT note earns ~0.000000951 USDT per second

### Repayment Priority

1. Interest owed (reduces to zero first)
2. Principal (reduces after interest cleared)
3. Interest rate recalculates based on new principal
4. When remaining principal < 1 USDT, note marked fully repaid with complete historical totals preserved

### Initial Schedule

- 6 tranches scheduled at launch
- Additional tranches require admin action
- No automatic continuation after scheduled tranches

---

## Constraints and Considerations

### Smart Contract Constraints

- APR is immutable once note is minted
- Tranche duration is fixed at 2 weeks
- Minimum 100 USDT prevents dust attacks
- Maximum deposit limited by remaining capacity
- Notes marked fully repaid (not destroyed) when principal < 1 USDT, preserving complete repayment history
- collectTranche is permissionless (anyone can call)

### Frontend Constraints

- Invite code is plaintext (intentionally not secure)
- Client-side only, no backend dependencies
- Must handle wallet disconnection gracefully
- Must show accurate real-time interest calculations

### Operational Constraints

- Vault must be funded before deposits for matching
- Admin must schedule tranches beyond initial 6
- Admin must call startFirstTranche to begin
- Collected funds transfer immediately on collectTranche

---

## Success Metrics

### On-Chain Metrics

- Total USDT deposited across all tranches
- Number of unique depositors
- Number of active donation notes
- Total interest paid to contributors
- Vault participation rate (matched vs unmatched)

### Frontend Metrics

- Invite code conversion rate
- Wallet connection rate
- Deposit completion rate
- Return visitor rate

### Ecosystem Metrics

- dApps launched from funded development
- Open source contributions (commits, PRs)
- Community engagement with funded projects

---

## Future Considerations

This proposal covers the initial implementation. Future enhancements may include:

- Variable APR per tranche based on demand
- Note marketplace for secondary trading
- Governance over dApp prioritization
- Integration with CL8Y token ecosystem
- Multi-chain expansion beyond BSC

These are not commitments but possibilities for evolution based on community feedback and ecosystem growth.
