import { type ReactNode, useEffect } from 'react';
import { WagmiProvider as WagmiProviderBase, useConnect, useAccount } from 'wagmi';
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
