import { createConfig, http } from 'wagmi';
import { injected, mock } from 'wagmi/connectors';
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
    default: { http: ['http://127.0.0.1:8545'] },
  },
} as const;

/**
 * Anvil account[0] - DO NOT use on mainnet!
 * This is a well-known test private key from Anvil/Hardhat
 */
const TEST_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const testAccount = privateKeyToAccount(TEST_PRIVATE_KEY);

/**
 * Check if we should use real wallet or mock
 * Set VITE_USE_REAL_WALLET=true to connect your own browser wallet
 */
const useRealWallet = import.meta.env.VITE_USE_REAL_WALLET === 'true';

/**
 * Wagmi config for test mode
 * Uses mock connector by default, or EIP-6963 injected wallets if VITE_USE_REAL_WALLET=true
 * 
 * EIP-6963 provides proper multi-wallet discovery without WalletConnect's data collection.
 * Each detected wallet (MetaMask, SafePal, Rabby, etc.) appears as a separate connector.
 */
export const testWagmiConfig = createConfig({
  chains: [anvilChain],
  connectors: useRealWallet
    ? [
        // EIP-6963: discovers all injected wallets automatically
        // Each wallet announces itself and appears as a separate option
        injected({
          shimDisconnect: true,
        }),
      ]
    : [
        mock({
          accounts: [testAccount.address],
        }),
      ],
  transports: {
    [anvilChain.id]: http('http://127.0.0.1:8545'),
  },
  ssr: false,
  // Enable EIP-6963 multi-injected provider discovery
  multiInjectedProviderDiscovery: true,
});

/**
 * Export test account info for reference
 */
export const TEST_ACCOUNT = {
  address: testAccount.address,
  privateKey: TEST_PRIVATE_KEY,
} as const;
