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

  // Get current tranche ID to know how many past tranches exist
  const { data: currentTrancheId } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'currentTrancheId',
    query: { enabled: !!trancheAddress },
  });

  const currentId = currentTrancheId ? Number(currentTrancheId) : 0;
  const pastTrancheCount = currentId > 1 ? currentId - 1 : 0;

  // Build contract calls for past tranches (IDs 1 to currentId-1)
  const trancheCalls = Array.from({ length: pastTrancheCount }, (_, index) => ({
    address: trancheAddress!,
    abi: DonationTrancheABI,
    functionName: 'getTranche' as const,
    args: [BigInt(index + 1)] as const,
  }));

  // Fetch all past tranches
  const { data: trancheResults, isLoading } = useReadContracts({
    contracts: trancheCalls,
    query: { enabled: pastTrancheCount > 0 && !!trancheAddress },
  });

  // Parse tranche results
  const pastTranches: TrancheInfo[] = trancheResults
    ?.map((result, index) => {
      if (result.status !== 'success' || !result.result) return null;
      const data = result.result as readonly [bigint, bigint, bigint, bigint, boolean, bigint];
      return {
        id: index + 1,
        startTime: Number(data[0]),
        endTime: Number(data[1]),
        cap: Number(data[2]) / 1e18,
        totalDeposited: Number(data[3]) / 1e18,
        collected: data[4],
        totalMatched: Number(data[5]) / 1e18,
      };
    })
    .filter((t): t is TrancheInfo => t !== null)
    .reverse() ?? []; // Most recent first

  if (!trancheAddress) {
    return null;
  }

  if (pastTrancheCount === 0) {
    return null; // No past tranches to show
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Past Tranches</CardTitle>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          {pastTrancheCount} completed tranche{pastTrancheCount !== 1 ? 's' : ''}
        </p>
      </CardHeader>

      <CardContent>
        {isLoading ? (
          <div className="text-center py-4">
            <p className="text-[var(--text-muted)]">Loading tranches...</p>
          </div>
        ) : (
          <div className="space-y-3">
            {pastTranches.map((tranche) => (
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
