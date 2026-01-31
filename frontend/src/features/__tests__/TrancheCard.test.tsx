import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { TrancheCard } from '../TrancheCard';

// Mock the config
vi.mock('@/lib/config', () => ({
  TRANCHE_CAP_USDT: 1584,
  DEFAULT_APR_PERCENT: 30,
}));

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
    render(<TrancheCard tranche={null} isConnected={true} />);
    expect(screen.getByText('No active tranche. Check back soon!')).toBeInTheDocument();
  });

  it('renders tranche information correctly', () => {
    render(<TrancheCard tranche={mockTranche} isConnected={true} />);
    expect(screen.getByText('Tranche #1')).toBeInTheDocument();
    expect(screen.getByText('Active')).toBeInTheDocument();
  });

  it('shows Contribute button when connected', () => {
    const mockOnDeposit = vi.fn();
    render(
      <TrancheCard 
        tranche={mockTranche} 
        isConnected={true} 
        onDeposit={mockOnDeposit}
      />
    );
    expect(screen.getByText('Contribute USDT')).toBeInTheDocument();
  });

  it('shows Connect Wallet button when not connected', () => {
    render(<TrancheCard tranche={mockTranche} isConnected={false} />);
    expect(screen.getByText('Connect Wallet to Contribute')).toBeInTheDocument();
  });

  it('shows progress bar', () => {
    render(<TrancheCard tranche={mockTranche} isConnected={true} />);
    expect(screen.getByText('Tranche Progress')).toBeInTheDocument();
    expect(screen.getByText('30% APR')).toBeInTheDocument();
  });

  it('shows matching info', () => {
    render(<TrancheCard tranche={mockTranche} isConnected={true} />);
    expect(screen.getByText('CZodiac Match')).toBeInTheDocument();
    expect(screen.getByText('1:1 Matched')).toBeInTheDocument();
  });

  it('shows full status when tranche is full', () => {
    const fullTranche = {
      ...mockTranche,
      totalDeposited: 1584,
    };
    render(<TrancheCard tranche={fullTranche} isConnected={true} />);
    expect(screen.getByText('Full - Ready for Collection')).toBeInTheDocument();
  });
});
