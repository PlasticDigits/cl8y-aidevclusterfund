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

// Operator addresses (comma-separated in env var) - these wallets can access admin dashboard
// TODO: Replace with on-chain AccessManager role check for better security
const operatorEnv = import.meta.env.VITE_OPERATOR_ADDRESSES as string | undefined;
export const OPERATOR_ADDRESSES: readonly string[] = operatorEnv
  ? operatorEnv.split(',').map(a => a.trim().toLowerCase())
  : [];

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
// AI + QA costs are funded; Audit/Review services are donated by Ceramic
export const FUNDING_MILESTONES = [
  {
    id: 1,
    name: 'BRIDGE v1: EVM to TerraClassic',
    aiCost: 931,
    qaCost: 367.5,
    auditCost: 1800,
    leadTimeWeeks: 2.8,
    cumulativeTotal: 1298.5,
  },
  {
    id: 2,
    name: 'DEX: V2+Hooks, Bot Friendly',
    aiCost: 1176,
    qaCost: 472.5,
    auditCost: 2400,
    leadTimeWeeks: 3.8,
    cumulativeTotal: 2947,
  },
  {
    id: 3,
    name: 'CMM: Auctions & Swaps',
    aiCost: 833,
    qaCost: 315,
    auditCost: 1800,
    leadTimeWeeks: 2.6,
    cumulativeTotal: 4095,
  },
  {
    id: 4,
    name: 'Dex Tools: LP Yield Bonding',
    aiCost: 490,
    qaCost: 210,
    auditCost: 1200,
    leadTimeWeeks: 1.6,
    cumulativeTotal: 4795,
  },
  {
    id: 5,
    name: 'Dex Tools: Timecurve Launchpad',
    aiCost: 441,
    qaCost: 157.5,
    auditCost: 600,
    leadTimeWeeks: 1.2,
    cumulativeTotal: 5393.5,
  },
  {
    id: 6,
    name: 'DAO NODES: Treasury + Governance',
    aiCost: 588,
    qaCost: 210,
    auditCost: 1200,
    leadTimeWeeks: 1.8,
    cumulativeTotal: 6191.5,
  },
  {
    id: 7,
    name: 'CL8Y Wallet: Crosschain Inbrowser Wallet',
    aiCost: 1274,
    qaCost: 525,
    auditCost: 3000,
    leadTimeWeeks: 4.2,
    cumulativeTotal: 7990.5,
  },
  {
    id: 8,
    name: 'GameFi: Text RPG Platform',
    aiCost: 1617,
    qaCost: 682.5,
    auditCost: 3600,
    leadTimeWeeks: 5.4,
    cumulativeTotal: 10290,
  },
  {
    id: 9,
    name: 'Money Market: Oracle-free',
    aiCost: 1078,
    qaCost: 420,
    auditCost: 2400,
    leadTimeWeeks: 3.4,
    cumulativeTotal: 11788,
  },
  {
    id: 10,
    name: 'PERP DEX: Hybrid Architecture',
    aiCost: 2254,
    qaCost: 945,
    auditCost: 5400,
    leadTimeWeeks: 7.6,
    cumulativeTotal: 14987,
  },
] as const;

export const TOTAL_FUNDING_TARGET = FUNDING_MILESTONES[FUNDING_MILESTONES.length - 1].cumulativeTotal;
export const TOTAL_AUDIT_DONATIONS = FUNDING_MILESTONES.reduce((sum, m) => sum + m.auditCost, 0);
