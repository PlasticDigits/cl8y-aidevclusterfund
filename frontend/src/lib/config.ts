// Test mode flag
const isTestMode = import.meta.env.VITE_TEST_MODE === 'true';

// Contract addresses
// In test mode, USDT address comes from deployed MockUSDT
export const ADDRESSES = {
  // USDT: Use env var in test mode (MockUSDT), BSC USDT otherwise
  USDT: (isTestMode && import.meta.env.VITE_USDT_ADDRESS
    ? import.meta.env.VITE_USDT_ADDRESS
    : '0x55d398326f99059fF775485246999027B3197955') as `0x${string}`,
  ACCESS_MANAGER: '0x5823a01A5372B779cB091e47DBBb176F2831b4c7' as const,
  CLUSTER_MANAGER: '0x30789c78b7640947db349e319991aaec416eeb93' as const,
  VAULT_OWNER: '0x745A676C5c472b50B50e18D4b59e9AeEEc597046' as const,
  // These will be set after deployment (or by devnet-start.sh in test mode)
  DONATION_TRANCHE: import.meta.env.VITE_DONATION_TRANCHE_ADDRESS as `0x${string}` | undefined,
  DONATION_VAULT: import.meta.env.VITE_DONATION_VAULT_ADDRESS as `0x${string}` | undefined,
} as const;

// Test mode helpers
export const IS_TEST_MODE = isTestMode;

// Anvil test accounts (for reference in test mode)
export const TEST_ACCOUNTS = {
  DEPLOYER: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as const,
  USER1: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8' as const,
  USER2: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC' as const,
} as const;

// Chain config
export const BSC_CHAIN_ID = 56;
export const ANVIL_CHAIN_ID = 31337;

// Expected chain - Anvil in test mode, BSC in production
export const EXPECTED_CHAIN_ID = isTestMode ? ANVIL_CHAIN_ID : BSC_CHAIN_ID;
export const EXPECTED_CHAIN_NAME = isTestMode ? 'Anvil (Local)' : 'BNB Smart Chain';

// Invite code
export const INVITE_CODE = 'donate';
export const INVITE_CODE_STORAGE_KEY = 'cl8y-fund-access';

// Tranche config
export const TRANCHE_DURATION_DAYS = 14;
export const DEFAULT_APR_PERCENT = 30;
export const TRANCHE_CAP_USDT = 1584;
export const MIN_DEPOSIT_USDT = 100;

// Funding milestones
export const FUNDING_MILESTONES = [
  {
    id: 1,
    name: 'BRIDGE v1: EVM to TerraClassic',
    aiCost: 931,
    qaCost: 1200,
    leadTimeDays: 7,
    cumulativeTotal: 2131,
  },
  {
    id: 2,
    name: 'DAO NODES: Treasury + Governance',
    aiCost: 588,
    qaCost: 1200,
    leadTimeDays: 5,
    cumulativeTotal: 3919,
  },
  {
    id: 3,
    name: 'DEX: V2+V3, Bot Friendly',
    aiCost: 1127,
    qaCost: 1800,
    leadTimeDays: 9,
    cumulativeTotal: 6846,
  },
  {
    id: 4,
    name: 'PERP DEX: Hybrid Architecture',
    aiCost: 2254,
    qaCost: 3000,
    leadTimeDays: 17,
    cumulativeTotal: 12100,
  },
  {
    id: 5,
    name: 'CMM: Auctions & Swaps',
    aiCost: 833,
    qaCost: 1200,
    leadTimeDays: 7,
    cumulativeTotal: 14133,
  },
  {
    id: 6,
    name: 'GameFi: Text RPG Platform',
    aiCost: 2695,
    qaCost: 4200,
    leadTimeDays: 21,
    cumulativeTotal: 21028,
  },
  {
    id: 7,
    name: 'Money Market: Oracle-free',
    aiCost: 1078,
    qaCost: 1800,
    leadTimeDays: 9,
    cumulativeTotal: 23906,
  },
] as const;

export const TOTAL_FUNDING_TARGET = FUNDING_MILESTONES[FUNDING_MILESTONES.length - 1].cumulativeTotal;
