import { useState } from 'react';
import { useReadContract, useReadContracts } from 'wagmi';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';

interface TrancheInfo {
  id: number;
  startTime: number;
  endTime: number;
  cap: number;
  totalDeposited: number;
  collected: boolean;
  totalMatched: number;
}

function formatDate(timestamp: number): string {
  return new Date(timestamp * 1000).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function PastTrancheCard({ tranche, isExpanded, onToggle }: { 
  tranche: TrancheInfo; 
  isExpanded: boolean;
  onToggle: () => void;
}) {
  const fillPercent = tranche.cap > 0 
    ? (tranche.totalDeposited / tranche.cap) * 100 
    : 0;

  return (
    <div 
      className="p-4 bg-[var(--charcoal)] rounded-lg border border-[var(--obsidian)] cursor-pointer hover:border-[var(--gold)]/30 transition-colors"
      onClick={onToggle}
    >
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <span className="text-[var(--gold)] font-bold">#{tranche.id}</span>
          <span className={`text-xs px-2 py-1 rounded ${
            tranche.collected 
              ? 'bg-green-500/20 text-green-400' 
              : 'bg-[var(--text-muted)]/20 text-[var(--text-muted)]'
          }`}>
            {tranche.collected ? 'Collected' : 'Ended'}
          </span>
        </div>
        <div className="text-right">
          <span className="text-[var(--text-secondary)] font-mono">
            {tranche.totalDeposited.toFixed(0)} USDT
          </span>
          <span className="text-[var(--text-muted)] text-sm ml-1">
            / {tranche.cap.toFixed(0)}
          </span>
        </div>
      </div>

      {isExpanded && (
        <div className="mt-4 pt-4 border-t border-[var(--obsidian)]">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-[var(--text-muted)]">Start Date</span>
              <p className="text-[var(--text-secondary)]">
                {formatDate(tranche.startTime)}
              </p>
            </div>
            <div>
              <span className="text-[var(--text-muted)]">End Date</span>
              <p className="text-[var(--text-secondary)]">
                {formatDate(tranche.endTime)}
              </p>
            </div>
            <div>
              <span className="text-[var(--text-muted)]">Fill Rate</span>
              <p className="text-[var(--text-secondary)]">{fillPercent.toFixed(1)}%</p>
            </div>
            <div>
              <span className="text-[var(--text-muted)]">Status</span>
              <p className={tranche.collected ? 'text-green-400' : 'text-[var(--text-muted)]'}>
                {tranche.collected ? 'Funds Deployed' : 'Pending Collection'}
              </p>
            </div>
          </div>

          <div className="mt-3">
            <div className="h-2 bg-[var(--obsidian)] rounded-full overflow-hidden">
              <div 
                className="h-full bg-[var(--gold)]/60 transition-all duration-300"
                style={{ width: `${fillPercent}%` }}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export function PastTranches() {
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

  // Get current tranche ID and whether it's collected
  const { data: currentTrancheId } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'currentTrancheId',
    query: { enabled: !!trancheAddress },
  });

  const { data: currentTrancheData } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getCurrentTranche',
    query: { enabled: !!trancheAddress },
  });

  const currentId = currentTrancheId ? Number(currentTrancheId) : 0;
  const currentCollected = currentTrancheData
    ? (currentTrancheData as readonly [bigint, bigint, bigint, bigint, bigint, bigint, boolean, boolean, bigint])[7]
    : false;

  // Completed tranches = all collected tranches from 1 to currentId (inclusive when current is collected)
  const trancheIdsToFetch = currentId === 0
    ? []
    : currentCollected
      ? Array.from({ length: currentId }, (_, i) => i + 1)
      : currentId > 1
        ? Array.from({ length: currentId - 1 }, (_, i) => i + 1)
        : [];

  // Build contract calls for completed tranches
  const trancheCalls = trancheIdsToFetch.map((id) => ({
    address: trancheAddress!,
    abi: DonationTrancheABI,
    functionName: 'getTranche' as const,
    args: [BigInt(id)] as const,
  }));

  // Fetch all completed tranches
  const { data: trancheResults, isLoading } = useReadContracts({
    contracts: trancheCalls,
    query: { enabled: trancheCalls.length > 0 && !!trancheAddress },
  });

  // Parse tranche results - only include collected tranches
  const completedTranches: TrancheInfo[] = trancheResults
    ?.map((result, index) => {
      if (result.status !== 'success' || !result.result) return null;
      const data = result.result as readonly [bigint, bigint, bigint, bigint, boolean, bigint];
      const id = trancheIdsToFetch[index];
      if (!data[4]) return null; // Not collected
      const info: TrancheInfo = {
        id,
        startTime: Number(data[0]),
        endTime: Number(data[1]),
        cap: Number(data[2]) / 1e18,
        totalDeposited: Number(data[3]) / 1e18,
        collected: true,
        totalMatched: Number(data[5]) / 1e18,
      };
      return info;
    })
    .filter((t): t is TrancheInfo => t !== null)
    .reverse() ?? [];

  if (!trancheAddress) {
    return null;
  }

  if (completedTranches.length === 0 && trancheCalls.length === 0) {
    return null; // No completed tranches to show
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Completed Tranches</CardTitle>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          {completedTranches.length} completed tranche{completedTranches.length !== 1 ? 's' : ''}
        </p>
      </CardHeader>

      <CardContent>
        {isLoading ? (
          <div className="text-center py-4">
            <p className="text-[var(--text-muted)]">Loading tranches...</p>
          </div>
        ) : (
          <div className="space-y-3">
            {completedTranches.map((tranche) => (
              <PastTrancheCard
                key={tranche.id}
                tranche={tranche}
                isExpanded={expandedId === tranche.id}
                onToggle={() => setExpandedId(
                  expandedId === tranche.id ? null : tranche.id
                )}
              />
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
