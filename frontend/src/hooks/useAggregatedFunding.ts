import { useReadContract, useReadContracts } from 'wagmi';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';

/**
 * Returns totalDeposited and totalMatched aggregated across all completed tranches,
 * plus the current tranche's amounts when it has deposits.
 */
export function useAggregatedFunding(currentTrancheDeposited: number, currentTrancheMatched: number) {
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;

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

  const trancheIdsToFetch = currentId === 0
    ? []
    : currentCollected
      ? Array.from({ length: currentId }, (_, i) => i + 1)
      : currentId > 1
        ? Array.from({ length: currentId - 1 }, (_, i) => i + 1)
        : [];

  const trancheCalls = trancheIdsToFetch.map((id) => ({
    address: trancheAddress!,
    abi: DonationTrancheABI,
    functionName: 'getTranche' as const,
    args: [BigInt(id)] as const,
  }));

  const { data: trancheResults } = useReadContracts({
    contracts: trancheCalls,
    query: { enabled: trancheCalls.length > 0 && !!trancheAddress },
  });

  let totalDeposited = 0;
  let totalMatched = 0;

  trancheResults?.forEach((result, index) => {
    if (result.status !== 'success' || !result.result) return;
    const data = result.result as readonly [bigint, bigint, bigint, bigint, boolean, bigint];
    if (!data[4]) return;
    totalDeposited += Number(data[3]) / 1e18;
    totalMatched += Number(data[5]) / 1e18;
  });

  if (!currentCollected && currentId >= 1) {
    totalDeposited += currentTrancheDeposited;
    totalMatched += currentTrancheMatched;
  }

  return { totalDeposited, totalMatched };
}
