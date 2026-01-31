import { useState, lazy, Suspense } from 'react';
import { useAccount, useReadContract } from 'wagmi';
import { AccessGate } from '@/components/AccessGate';
import { ErrorBoundary, CompactErrorBoundary } from '@/components/ErrorBoundary';
import { WalletConnect } from '@/features/WalletConnect';
import { Hero } from '@/features/Hero';
import { TrancheCard } from '@/features/TrancheCard';
import { FundingTimeline } from '@/features/FundingTimeline';
import { MyNotes } from '@/features/MyNotes';
import { PastTranches } from '@/features/PastTranches';
import { ScheduledTranches } from '@/features/ScheduledTranches';
import { DepositModal } from '@/features/DepositModal';
import { PortfolioSummary } from '@/features/PortfolioSummary';
import { ADDRESSES, TRANCHE_CAP_USDT, IS_TEST_MODE } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { parseEther } from 'viem';

// Lazy load admin components
const AdminDashboard = lazy(() => import('@/features/AdminDashboard').then(m => ({ default: m.AdminDashboard })));
const VaultDashboard = lazy(() => import('@/features/VaultDashboard').then(m => ({ default: m.VaultDashboard })));

function Dashboard() {
  const [isDepositOpen, setIsDepositOpen] = useState(false);
  const [showAdmin, setShowAdmin] = useState(false);
  const { address, isConnected } = useAccount();
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

  // Check if user is admin (authority of the contract)
  const { data: authority } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'authority',
    query: { enabled: !!trancheAddress },
  });

  // In test mode, deployer is admin
  const isAdmin = IS_TEST_MODE 
    ? address?.toLowerCase() === '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'.toLowerCase()
    : authority?.toLowerCase() === address?.toLowerCase();

  // Read current tranche data
  const { data: trancheData, refetch: refetchTranche } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getCurrentTranche',
    query: { enabled: !!trancheAddress },
  });

  // Read scheduled tranches
  const { data: scheduledData, refetch: refetchScheduled } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getScheduledTranches',
    query: { enabled: !!trancheAddress },
  });

  // Handler for when a new tranche is started
  const handleTrancheStarted = () => {
    refetchTranche();
    refetchScheduled();
  };

  // Parse scheduled tranches
  type ScheduledResult = readonly [readonly bigint[], readonly bigint[]];
  const scheduledResult = scheduledData as ScheduledResult | undefined;
  const scheduledTranches = scheduledResult
    ? scheduledResult[0].map((startTime, i) => ({
        startTime: Number(startTime),
        endTime: Number(scheduledResult[1][i]),
      }))
    : [];

  // Parse tranche data - result is a tuple
  type TrancheResult = readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint];
  const trancheResult = trancheData as TrancheResult | undefined;
  
  const tranche = trancheResult
    ? {
        id: Number(trancheResult[0]),
        startTime: Number(trancheResult[1]),
        endTime: Number(trancheResult[2]),
        cap: Number(trancheResult[3]) / 1e18,
        totalDeposited: Number(trancheResult[4]) / 1e18,
        remaining: Number(trancheResult[5]),
        isActive: trancheResult[6],
        collected: trancheResult[7],
        totalMatched: Number(trancheResult[8]) / 1e18,
      }
    : null;

  // For demo/preview when contract not deployed
  // Use lazy state initializer to capture time once on mount
  const [demoStartTime] = useState(() => Math.floor(Date.now() / 1000));
  const demoTranche = !trancheAddress
    ? {
        id: 1,
        startTime: demoStartTime,
        endTime: demoStartTime + 14 * 24 * 60 * 60,
        cap: TRANCHE_CAP_USDT,
        totalDeposited: 400,
        isActive: true,
        collected: false,
        totalMatched: 200,
      }
    : null;

  const displayTranche = tranche || demoTranche;

  // Calculate total raised (simplified - would aggregate all tranches in production)
  const totalRaised = displayTranche ? displayTranche.totalDeposited : 0;

  const remainingCapacity = trancheResult
    ? trancheResult[5]
    : parseEther(TRANCHE_CAP_USDT.toString());

  return (
    <div className="min-h-screen bg-[var(--black)]">
      {/* Demo data alert */}
      {!trancheAddress && (
        <div className="bg-yellow-500/20 border-b border-yellow-500/50 text-yellow-200 px-4 py-2 text-center text-sm">
          SHOWING DEMO DATA ONLY - Contract not deployed. Set VITE_DONATION_TRANCHE_ADDRESS in .env
        </div>
      )}

      {/* Header */}
      <header className="border-b border-[var(--charcoal)]">
        <div className="max-w-6xl mx-auto px-4 py-4 flex justify-between items-center">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <img 
                src="/images/CLAY-64.png" 
                alt="CL8Y" 
                className="w-8 h-8"
              />
              <span className="text-xl font-bold font-display text-[var(--gold)]">
                CL8Y
              </span>
              <span className="text-[var(--text-muted)]">Fund</span>
            </div>
            {/* Admin toggle - only visible to admins */}
            {isAdmin && isConnected && (
              <button
                onClick={() => setShowAdmin(!showAdmin)}
                className={`text-xs px-3 py-1 rounded border transition-colors ${
                  showAdmin 
                    ? 'border-[var(--gold)] text-[var(--gold)] bg-[var(--gold)]/10' 
                    : 'border-[var(--charcoal)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]'
                }`}
              >
                Admin
              </button>
            )}
          </div>
          <WalletConnect />
        </div>
      </header>

      {/* Hero */}
      <Hero />

      {/* Admin Dashboard - Lazy loaded */}
      {showAdmin && isAdmin && (
        <Suspense fallback={
          <div className="max-w-6xl mx-auto px-4 py-6">
            <div className="animate-pulse bg-[var(--charcoal)] h-64 rounded-lg" />
          </div>
        }>
          <div className="max-w-6xl mx-auto px-4 py-6 space-y-6">
            <ErrorBoundary>
              <AdminDashboard />
            </ErrorBoundary>
            <ErrorBoundary>
              <VaultDashboard />
            </ErrorBoundary>
          </div>
        </Suspense>
      )}

      {/* Main Content */}
      <main className="max-w-6xl mx-auto px-4 py-8">
        <div className="grid lg:grid-cols-3 gap-6">
          {/* Left column - Tranche */}
          <div className="lg:col-span-2 space-y-6">
            <TrancheCard
              tranche={displayTranche}
              isConnected={isConnected}
              onDeposit={() => setIsDepositOpen(true)}
            />

            {scheduledTranches.length > 0 && (
              <CompactErrorBoundary>
                <ScheduledTranches
                  currentTrancheId={displayTranche?.id || 0}
                  scheduledTranches={scheduledTranches}
                  onTrancheStarted={handleTrancheStarted}
                />
              </CompactErrorBoundary>
            )}

            <CompactErrorBoundary>
              <PastTranches />
            </CompactErrorBoundary>

            <FundingTimeline totalRaised={totalRaised} />
          </div>

          {/* Right column - Notes */}
          <div className="space-y-6">
            <CompactErrorBoundary>
              <PortfolioSummary />
            </CompactErrorBoundary>
            <CompactErrorBoundary>
              <MyNotes />
            </CompactErrorBoundary>

            {/* Info card */}
            <div className="card">
              <h3 className="font-bold text-[var(--text-primary)] mb-3">
                How It Works
              </h3>
              <ol className="space-y-2 text-sm text-[var(--text-secondary)]">
                <li className="flex gap-2">
                  <span className="text-[var(--gold)]">1.</span>
                  <span>Connect your wallet and deposit USDT</span>
                </li>
                <li className="flex gap-2">
                  <span className="text-[var(--gold)]">2.</span>
                  <span>Receive an NFT donation note with 30% APR</span>
                </li>
                <li className="flex gap-2">
                  <span className="text-[var(--gold)]">3.</span>
                  <span>Your deposit is matched 1:1 by CZodiac</span>
                </li>
                <li className="flex gap-2">
                  <span className="text-[var(--gold)]">4.</span>
                  <span>Funds go to AI dev cluster for open source projects</span>
                </li>
                <li className="flex gap-2">
                  <span className="text-[var(--gold)]">5.</span>
                  <span>Earn rewards as notes are repaid</span>
                </li>
              </ol>
            </div>

            {/* Stats */}
            <div className="card">
              <h3 className="font-bold text-[var(--text-primary)] mb-3">
                Quick Stats
              </h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">APR</span>
                  <span className="font-mono text-[var(--aqua)]">30%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Tranche Duration</span>
                  <span className="font-mono text-[var(--text-primary)]">2 weeks</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Matching</span>
                  <span className="font-mono text-[var(--text-primary)]">1:1</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Min Deposit</span>
                  <span className="font-mono text-[var(--text-primary)]">100 USDT</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Services Matching</span>
                  <span className="font-mono text-[var(--ember)]">1.5x</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-[var(--charcoal)] mt-12">
        <div className="max-w-6xl mx-auto px-4 py-6 text-center text-sm text-[var(--text-muted)]">
          <p>
            All funded development is AGPL open source for public research and education.
          </p>
          <p className="mt-2">
            Smart contracts are public and auditable on BSC.
          </p>
        </div>
      </footer>

      {/* Deposit Modal */}
      <ErrorBoundary>
        <DepositModal
          isOpen={isDepositOpen}
          onClose={() => setIsDepositOpen(false)}
          remainingCapacity={remainingCapacity}
          onSuccess={() => refetchTranche()}
        />
      </ErrorBoundary>
    </div>
  );
}

function App() {
  return (
    <ErrorBoundary>
      <AccessGate>
        <Dashboard />
      </AccessGate>
    </ErrorBoundary>
  );
}

export default App;
