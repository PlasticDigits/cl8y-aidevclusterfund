import { type ReactNode, useEffect } from 'react';
import { WagmiProvider as WagmiProviderBase, createConfig, http, useConnect, useAccount } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { mock } from 'wagmi/connectors';
import { privateKeyToAccount } from 'viem/accounts';

/**
 * Anvil local chain configuration
 * ChainId 31337 is the default for Anvil/Hardhat
 */
const anvilChain = {
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

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5_000, // Shorter stale time for testing
      gcTime: 5 * 60_000,
    },
  },
});

/**
 * Auto-connect component
 * Automatically connects to the mock wallet on mount
 */
function AutoConnect({ children }: { children: ReactNode }) {
  const { connect, connectors } = useConnect();
  const { isConnected } = useAccount();

  useEffect(() => {
    if (!isConnected && connectors.length > 0) {
      // Auto-connect to the first (mock) connector
      connect({ connector: connectors[0] });
    }
  }, [connect, connectors, isConnected]);

  return <>{children}</>;
}

interface Props {
  children: ReactNode;
}

/**
 * Test wallet provider for local Anvil testing
 * Auto-connects with a test wallet, no popups or user interaction needed
 */
export function TestWalletProvider({ children }: Props) {
  return (
    <WagmiProviderBase config={testWagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <AutoConnect>{children}</AutoConnect>
      </QueryClientProvider>
    </WagmiProviderBase>
  );
}

/**
 * Export test account info for reference
 */
export const TEST_ACCOUNT = {
  address: testAccount.address,
  privateKey: TEST_PRIVATE_KEY,
} as const;
