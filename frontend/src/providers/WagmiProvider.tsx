import { type ReactNode } from 'react';
import { WagmiProvider as WagmiProviderBase } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { TestWalletProvider } from './TestWalletProvider';
import { wagmiConfig } from '@/lib/wagmiConfig';

const isTestMode = import.meta.env.VITE_TEST_MODE === 'true';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      gcTime: 5 * 60_000,
    },
  },
});

interface Props {
  children: ReactNode;
}

/**
 * Smart provider that uses TestWalletProvider in test mode
 * and production WagmiProvider otherwise
 */
export function WagmiProvider({ children }: Props) {
  // Use test provider for local Anvil testing
  if (isTestMode) {
    return <TestWalletProvider>{children}</TestWalletProvider>;
  }

  // Production provider with real wallet connectors
  return (
    <WagmiProviderBase config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProviderBase>
  );
}
