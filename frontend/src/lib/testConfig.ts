import { createConfig, http } from 'wagmi';
import { mock } from 'wagmi/connectors';
import { privateKeyToAccount } from 'viem/accounts';

/**
 * Anvil local chain configuration
 * ChainId 31337 is the default for Anvil/Hardhat
 */
export const anvilChain = {
  id: 31337,
  name: 'Anvil',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
  },
} as const;

/**
 * Anvil account[0] - DO NOT use on mainnet!
 * This is a well-known test private key from Anvil/Hardhat
 */
const TEST_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const testAccount = privateKeyToAccount(TEST_PRIVATE_KEY);

/**
 * Wagmi config for test mode
 * Uses mock connector with Anvil's default account
 */
export const testWagmiConfig = createConfig({
  chains: [anvilChain],
  connectors: [
    mock({
      accounts: [testAccount.address],
    }),
  ],
  transports: {
    [anvilChain.id]: http('http://localhost:8545'),
  },
  ssr: false,
});

/**
 * Export test account info for reference
 */
export const TEST_ACCOUNT = {
  address: testAccount.address,
  privateKey: TEST_PRIVATE_KEY,
} as const;
