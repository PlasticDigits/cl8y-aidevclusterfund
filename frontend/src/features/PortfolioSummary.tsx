import { useMemo } from 'react';
import { useAccount, useReadContract, useReadContracts, useBlockNumber } from 'wagmi';
import { formatUnits } from 'viem';
import { TokenIcon } from '@/components/ui/TokenIcon';
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

  // Watch for new blocks to trigger refetches
  useBlockNumber({ watch: true });

  // Get balance of notes with refetch on block changes
  const { data: noteBalance } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { 
      enabled: !!address && !!trancheAddress,
      refetchInterval: 3000, // Poll every 3 seconds
    },
  });

  const noteCount = noteBalance ? Number(noteBalance) : 0;

  // Build contract calls for token IDs
  const tokenIdCalls = useMemo(() => 
    Array.from({ length: noteCount }, (_, index) => ({
      address: trancheAddress!,
      abi: DonationTrancheABI,
      functionName: 'tokenOfOwnerByIndex' as const,
      args: [address!, BigInt(index)] as const,
    })), [noteCount, trancheAddress, address]);

  // Fetch all token IDs
  const { data: tokenIdResults } = useReadContracts({
    contracts: tokenIdCalls,
    query: { 
      enabled: noteCount > 0 && !!address && !!trancheAddress,
      refetchInterval: 3000,
    },
  });

  // Extract token IDs from results - memoized to avoid dependency changes
  const tokenIds: bigint[] = useMemo(() => {
    return tokenIdResults
      ?.map(result => result.status === 'success' ? result.result as bigint : null)
      .filter((id): id is bigint => id !== null) ?? [];
  }, [tokenIdResults]);

  // Build contract calls for note info
  const noteInfoCalls = useMemo(() => 
    tokenIds.map(tokenId => ({
      address: trancheAddress!,
      abi: DonationTrancheABI,
      functionName: 'getNoteInfo' as const,
      args: [tokenId] as const,
    })), [tokenIds, trancheAddress]);

  // Fetch all note info
  const { data: noteInfoResults, isLoading } = useReadContracts({
    contracts: noteInfoCalls,
    query: { 
      enabled: tokenIds.length > 0 && !!trancheAddress,
      refetchInterval: 3000,
    },
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
      <div className="mb-4 p-3 bg-[var(--charcoal)] rounded-lg border border-[var(--gold)]/20 animate-pulse">
        <div className="h-4 bg-[var(--obsidian)] rounded w-1/3"></div>
      </div>
    );
  }

  return (
    <div className="mb-4 p-2 bg-[var(--charcoal)] rounded-lg border border-[var(--gold)]/20 overflow-x-auto scrollbar-themed">
      <div className="flex items-center gap-3 text-xs whitespace-nowrap min-w-0">
        {/* Title */}
        <div className="flex items-center gap-1.5 shrink-0">
          <TokenIcon token="CL8Y" size="sm" />
          <span className="font-medium text-[var(--text-primary)]">Portfolio</span>
          <span className="text-[var(--text-muted)]">
            ({stats.activeNotes}{stats.completedNotes > 0 ? `+${stats.completedNotes}` : ''})
          </span>
        </div>

        <span className="text-[var(--charcoal)]">|</span>

        {/* Stats */}
        <div className="flex items-center gap-1 shrink-0">
          <TokenIcon token="USDT" size="xs" />
          <span className="text-[var(--text-primary)] font-medium">
            {stats.totalPrincipal.toLocaleString(undefined, { maximumFractionDigits: 0 })}
          </span>
        </div>

        <span className="text-[var(--text-muted)]">→</span>

        <div className="flex items-center gap-1 shrink-0">
          <TokenIcon token="USDT" size="xs" />
          <span className="text-[var(--gold)] font-medium">
            {stats.outstandingValue.toLocaleString(undefined, { maximumFractionDigits: 1 })}
          </span>
        </div>

        <span className="text-green-400 font-medium shrink-0">
          +{stats.totalInterestEarned.toLocaleString(undefined, { maximumFractionDigits: 2 })}
        </span>

        <span className="text-[var(--text-muted)] shrink-0">
          {stats.weightedApr.toFixed(0)}%
        </span>
      </div>
    </div>
  );
}
