import { type ReactNode } from 'react';
import { WagmiProvider as WagmiProviderBase, createConfig, http } from 'wagmi';
import { bsc } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { injected, walletConnect } from 'wagmi/connectors';
import { TestWalletProvider } from './TestWalletProvider';

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;
const isTestMode = import.meta.env.VITE_TEST_MODE === 'true';

const connectors = projectId
  ? [injected(), walletConnect({ projectId })]
  : [injected()];

export const wagmiConfig = createConfig({
  chains: [bsc],
  connectors,
  transports: {
    [bsc.id]: http(import.meta.env.VITE_BSC_RPC_URL || 'https://bsc-dataseed.binance.org'),
  },
  ssr: false,
});

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
