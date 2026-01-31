import { useMemo } from 'react';
import { useAccount, useReadContract, useReadContracts } from 'wagmi';
import { formatUnits } from 'viem';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';

interface NoteInfo {
  tokenId: bigint;
  trancheId: bigint;
  aprBps: bigint;
  interestOwed: bigint;
  principal: bigint;
  principalRepaid: bigint;
  interestPaid: bigint;
  interestAccrued: bigint;
  remainingPrincipal: bigint;
  fullyRepaid: boolean;
}

export function PortfolioSummary() {
  const { address, isConnected } = useAccount();
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

  // Get balance of notes
  const { data: noteBalance } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!trancheAddress },
  });

  const noteCount = noteBalance ? Number(noteBalance) : 0;

  // Build contract calls for token IDs
  const tokenIdCalls = Array.from({ length: noteCount }, (_, index) => ({
    address: trancheAddress!,
    abi: DonationTrancheABI,
    functionName: 'tokenOfOwnerByIndex' as const,
    args: [address!, BigInt(index)] as const,
  }));

  // Fetch all token IDs
  const { data: tokenIdResults } = useReadContracts({
    contracts: tokenIdCalls,
    query: { enabled: noteCount > 0 && !!address && !!trancheAddress },
  });

  // Extract token IDs from results - memoized to avoid dependency changes
  const tokenIds: bigint[] = useMemo(() => {
    return tokenIdResults
      ?.map(result => result.status === 'success' ? result.result as bigint : null)
      .filter((id): id is bigint => id !== null) ?? [];
  }, [tokenIdResults]);

  // Build contract calls for note info
  const noteInfoCalls = tokenIds.map(tokenId => ({
    address: trancheAddress!,
    abi: DonationTrancheABI,
    functionName: 'getNoteInfo' as const,
    args: [tokenId] as const,
  }));

  // Fetch all note info
  const { data: noteInfoResults, isLoading } = useReadContracts({
    contracts: noteInfoCalls,
    query: { enabled: tokenIds.length > 0 && !!trancheAddress },
  });

  // Parse note info results
  const notes: NoteInfo[] = useMemo(() => {
    return noteInfoResults
      ?.map((result, index) => {
        if (result.status !== 'success' || !result.result) return null;
        const data = result.result as readonly [
          string, bigint, bigint, bigint, bigint, bigint,
          bigint, bigint, bigint, bigint, bigint, bigint, boolean, bigint
        ];
        return {
          tokenId: tokenIds[index],
          trancheId: data[1],
          aprBps: data[2],
          interestOwed: data[4],
          principal: data[6],
          principalRepaid: data[7],
          interestPaid: data[8],
          interestAccrued: data[9],
          remainingPrincipal: data[10],
          fullyRepaid: data[12],
        };
      })
      .filter((note): note is NoteInfo => note !== null) ?? [];
  }, [noteInfoResults, tokenIds]);

  // Calculate aggregate statistics
  const stats = useMemo(() => {
    if (notes.length === 0) {
      return {
        totalNotes: 0,
        activeNotes: 0,
        completedNotes: 0,
        totalPrincipal: 0,
        totalInterestEarned: 0,
        totalPrincipalRepaid: 0,
        outstandingValue: 0,
        weightedApr: 0,
      };
    }

    let totalPrincipal = BigInt(0);
    let totalInterestEarned = BigInt(0);
    let totalPrincipalRepaid = BigInt(0);
    let totalInterestOwed = BigInt(0);
    let totalRemainingPrincipal = BigInt(0);
    let weightedAprSum = BigInt(0);
    let activeNotes = 0;
    let completedNotes = 0;

    for (const note of notes) {
      totalPrincipal += note.principal;
      totalInterestEarned += note.interestPaid;
      totalPrincipalRepaid += note.principalRepaid;
      totalInterestOwed += note.interestOwed;
      totalRemainingPrincipal += note.remainingPrincipal;
      weightedAprSum += note.aprBps * note.principal;

      if (note.fullyRepaid) {
        completedNotes++;
      } else {
        activeNotes++;
      }
    }

    const outstandingValue = totalRemainingPrincipal + totalInterestOwed;
    const weightedApr = totalPrincipal > 0 
      ? Number(weightedAprSum / totalPrincipal) / 100 
      : 0;

    return {
      totalNotes: notes.length,
      activeNotes,
      completedNotes,
      totalPrincipal: Number(formatUnits(totalPrincipal, 18)),
      totalInterestEarned: Number(formatUnits(totalInterestEarned, 18)),
      totalPrincipalRepaid: Number(formatUnits(totalPrincipalRepaid, 18)),
      outstandingValue: Number(formatUnits(outstandingValue, 18)),
      weightedApr,
    };
  }, [notes]);

  // Don't show if not connected or no notes
  if (!isConnected || noteCount === 0) {
    return null;
  }

  if (isLoading) {
    return (
      <Card className="mb-6">
        <CardContent className="py-6">
          <div className="animate-pulse flex space-x-4">
            <div className="flex-1 space-y-4 py-1">
              <div className="h-4 bg-[var(--charcoal)] rounded w-3/4"></div>
              <div className="space-y-3">
                <div className="grid grid-cols-3 gap-4">
                  <div className="h-4 bg-[var(--charcoal)] rounded col-span-1"></div>
                  <div className="h-4 bg-[var(--charcoal)] rounded col-span-1"></div>
                  <div className="h-4 bg-[var(--charcoal)] rounded col-span-1"></div>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="mb-6 border-[var(--gold)]/20">
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Portfolio Summary</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {/* Total Principal */}
          <div className="p-3 bg-[var(--charcoal)] rounded-lg">
            <p className="text-xs text-[var(--text-muted)] mb-1">Total Invested</p>
            <p className="text-lg font-semibold text-[var(--text-primary)]">
              {stats.totalPrincipal.toLocaleString(undefined, { maximumFractionDigits: 2 })}
              <span className="text-sm font-normal text-[var(--text-muted)]"> USDT</span>
            </p>
          </div>

          {/* Outstanding Value */}
          <div className="p-3 bg-[var(--charcoal)] rounded-lg">
            <p className="text-xs text-[var(--text-muted)] mb-1">Current Value</p>
            <p className="text-lg font-semibold text-[var(--gold)]">
              {stats.outstandingValue.toLocaleString(undefined, { maximumFractionDigits: 2 })}
              <span className="text-sm font-normal text-[var(--text-muted)]"> USDT</span>
            </p>
          </div>

          {/* Interest Earned */}
          <div className="p-3 bg-[var(--charcoal)] rounded-lg">
            <p className="text-xs text-[var(--text-muted)] mb-1">Interest Earned</p>
            <p className="text-lg font-semibold text-green-400">
              +{stats.totalInterestEarned.toLocaleString(undefined, { maximumFractionDigits: 4 })}
              <span className="text-sm font-normal text-[var(--text-muted)]"> USDT</span>
            </p>
          </div>

          {/* Average APR */}
          <div className="p-3 bg-[var(--charcoal)] rounded-lg">
            <p className="text-xs text-[var(--text-muted)] mb-1">Avg APR</p>
            <p className="text-lg font-semibold text-[var(--text-primary)]">
              {stats.weightedApr.toFixed(1)}%
            </p>
          </div>
        </div>

        {/* Secondary Stats */}
        <div className="mt-4 flex flex-wrap gap-4 text-sm">
          <div className="flex items-center gap-2">
            <span className="text-[var(--text-muted)]">Notes:</span>
            <span className="text-[var(--text-secondary)]">
              {stats.activeNotes} active
              {stats.completedNotes > 0 && `, ${stats.completedNotes} completed`}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-[var(--text-muted)]">Principal Repaid:</span>
            <span className="text-[var(--text-secondary)]">
              {stats.totalPrincipalRepaid.toLocaleString(undefined, { maximumFractionDigits: 2 })} USDT
            </span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
