import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createConfig, http } from 'wagmi';
import { mock } from 'wagmi/connectors';
import { TrancheCard } from '../TrancheCard';

// Mock the config
vi.mock('@/lib/config', () => ({
  TRANCHE_CAP_USDT: 1584,
  DEFAULT_APR_PERCENT: 30,
}));

// Create a minimal wagmi config for tests
const testChain = {
  id: 31337,
  name: 'Test',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: ['http://127.0.0.1:8545'] } },
} as const;

const testConfig = createConfig({
  chains: [testChain],
  connectors: [mock({ accounts: ['0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'] })],
  transports: { [testChain.id]: http() },
});

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false } },
});

function TestWrapper({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={testConfig}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
}

function renderWithProviders(ui: React.ReactElement) {
  return render(ui, { wrapper: TestWrapper });
}

describe('TrancheCard', () => {
  const mockTranche = {
    id: 1,
    startTime: Math.floor(Date.now() / 1000) - 3600, // 1 hour ago
    endTime: Math.floor(Date.now() / 1000) + 86400, // 24 hours from now
    cap: 1584,
    totalDeposited: 500,
    isActive: true,
    collected: false,
  };

  it('shows loading state when no tranche data', () => {
    renderWithProviders(<TrancheCard tranche={null} isConnected={true} />);
    expect(screen.getByText('No active tranche. Check back soon!')).toBeInTheDocument();
  });

  it('renders tranche information correctly', () => {
    renderWithProviders(<TrancheCard tranche={mockTranche} isConnected={true} />);
    expect(screen.getByText('Tranche #1')).toBeInTheDocument();
    expect(screen.getByText('Active')).toBeInTheDocument();
  });

  it('shows Contribute button when connected', () => {
    const mockOnDeposit = vi.fn();
    renderWithProviders(
      <TrancheCard 
        tranche={mockTranche} 
        isConnected={true} 
        onDeposit={mockOnDeposit}
      />
    );
    expect(screen.getByText('Contribute USDT')).toBeInTheDocument();
  });

  it('shows Connect Wallet button when not connected', () => {
    renderWithProviders(<TrancheCard tranche={mockTranche} isConnected={false} />);
    expect(screen.getByText('Connect Wallet to Contribute')).toBeInTheDocument();
  });

  it('shows progress bar', () => {
    renderWithProviders(<TrancheCard tranche={mockTranche} isConnected={true} />);
    expect(screen.getByText('Tranche Progress')).toBeInTheDocument();
    expect(screen.getByText('30% APR')).toBeInTheDocument();
  });

  it('shows matching info', () => {
    renderWithProviders(<TrancheCard tranche={mockTranche} isConnected={true} />);
    expect(screen.getByText('CZodiac Match')).toBeInTheDocument();
    expect(screen.getByText('1:1 Matched')).toBeInTheDocument();
  });

  it('shows full status when tranche is full', () => {
    const fullTranche = {
      ...mockTranche,
      totalDeposited: 1584,
    };
    renderWithProviders(<TrancheCard tranche={fullTranche} isConnected={true} />);
    expect(screen.getByText('Full - Ready for Collection')).toBeInTheDocument();
  });
});
