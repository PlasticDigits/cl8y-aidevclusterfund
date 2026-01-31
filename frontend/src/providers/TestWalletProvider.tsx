import { type ReactNode } from 'react';
import { WagmiProvider as WagmiProviderBase } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { testWagmiConfig } from '@/lib/testConfig';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5_000, // Shorter stale time for testing
      gcTime: 5 * 60_000,
    },
  },
});

interface Props {
  children: ReactNode;
}

/**
 * Test wallet provider for local Anvil testing
 * 
 * Provides both options in the UI:
 * - Real browser wallets via EIP-6963 (MetaMask, SafePal, etc.)
 * - Mock wallet using Anvil's default test account
 * 
 * Users choose at runtime - no auto-connect.
 */
export function TestWalletProvider({ children }: Props) {
  return (
    <WagmiProviderBase config={testWagmiConfig}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProviderBase>
  );
}
