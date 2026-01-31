import { useState, useMemo } from 'react';
import { useAccount, useReadContract, useReadContracts, useBlockNumber } from 'wagmi';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { TokenIcon } from '@/components/ui/TokenIcon';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { formatUnits } from 'viem';
import { TransferModal } from './TransferModal';

interface NoteInfo {
  tokenId: bigint;
  owner: string;
  trancheId: bigint;
  aprBps: bigint;
  timestamp: bigint;
  interestOwed: bigint;
  interestPerSecond: bigint;
  principal: bigint;
  principalRepaid: bigint;
  interestPaid: bigint;
  interestAccrued: bigint;
  remainingPrincipal: bigint;
  totalRepaid: bigint;
  fullyRepaid: boolean;
  completedTimestamp: bigint;
}

export function MyNotes() {
  const { address, isConnected } = useAccount();
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;
  const [transferTokenId, setTransferTokenId] = useState<bigint | null>(null);

  // Watch for new blocks to trigger refetches
  useBlockNumber({ watch: true });

  // Get balance of notes with polling
  const { data: noteBalance, refetch: refetchBalance } = useReadContract({
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

  // Extract token IDs from results
  const tokenIds: bigint[] = useMemo(() => 
    tokenIdResults
      ?.map(result => result.status === 'success' ? result.result as bigint : null)
      .filter((id): id is bigint => id !== null) ?? [],
  [tokenIdResults]);

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
  const notes: NoteInfo[] = useMemo(() => 
    noteInfoResults
      ?.map((result, index) => {
        if (result.status !== 'success' || !result.result) return null;
        const data = result.result as readonly [
          string, bigint, bigint, bigint, bigint, bigint, 
          bigint, bigint, bigint, bigint, bigint, bigint, boolean, bigint
        ];
        return {
          tokenId: tokenIds[index],
          owner: data[0],
          trancheId: data[1],
          aprBps: data[2],
          timestamp: data[3],
          interestOwed: data[4],
          interestPerSecond: data[5],
          principal: data[6],
          principalRepaid: data[7],
          interestPaid: data[8],
          interestAccrued: data[9],
          remainingPrincipal: data[10],
          totalRepaid: data[11],
          fullyRepaid: data[12],
          completedTimestamp: data[13],
        };
      })
      .filter((note): note is NoteInfo => note !== null) ?? [],
  [noteInfoResults, tokenIds]);

  if (!isConnected) {
    return (
      <Card>
        <CardContent className="text-center py-6">
          <p className="text-sm text-[var(--text-muted)]">
            Connect your wallet to view your donation notes
          </p>
        </CardContent>
      </Card>
    );
  }

  if (!trancheAddress) {
    return (
      <Card>
        <CardContent className="text-center py-6">
          <p className="text-sm text-[var(--text-muted)]">
            Contract not deployed yet
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-base">My Notes</CardTitle>
          <span className="text-xs text-[var(--text-muted)]">
            {noteCount} note{noteCount !== 1 ? 's' : ''}
          </span>
        </div>
      </CardHeader>

      <CardContent className="pt-0">
        {isLoading ? (
          <div className="animate-pulse space-y-2">
            <div className="h-8 bg-[var(--charcoal)] rounded"></div>
            <div className="h-8 bg-[var(--charcoal)] rounded"></div>
          </div>
        ) : noteCount === 0 ? (
          <div className="text-center py-4">
            <p className="text-sm text-[var(--text-muted)]">
              No notes yet. Contribute to a tranche to receive your first note.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto scrollbar-themed">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-[10px] text-[var(--text-muted)] border-b border-[var(--charcoal)]">
                  <th className="pb-1.5 pr-2">#</th>
                  <th className="pb-1.5 pr-2">Principal</th>
                  <th className="pb-1.5 pr-2">APR</th>
                  <th className="pb-1.5 pr-2">Owed</th>
                  <th className="pb-1.5 pr-2">Repaid</th>
                  <th className="pb-1.5 pr-2"></th>
                  <th className="pb-1.5"></th>
                </tr>
              </thead>
              <tbody>
                {notes.map((note) => {
                  const principal = Number(formatUnits(note.principal, 18));
                  const interestOwed = Number(formatUnits(note.interestOwed, 18));
                  const aprPercent = Number(note.aprBps) / 100;
                  const repaidPercent = principal > 0 
                    ? ((principal - Number(formatUnits(note.remainingPrincipal, 18))) / principal) * 100 
                    : 0;

                  return (
                    <tr 
                      key={note.tokenId.toString()} 
                      className="border-b border-[var(--charcoal)] last:border-0 hover:bg-[var(--charcoal)]/50"
                    >
                      <td className="py-1.5 pr-2">
                        <span className="text-[var(--text-muted)]">{note.tokenId.toString()}</span>
                      </td>
                      <td className="py-1.5 pr-2">
                        <div className="flex items-center gap-1">
                          <TokenIcon token="USDT" size="xs" />
                          <span className="text-[var(--gold)] font-medium">
                            {principal.toLocaleString(undefined, { maximumFractionDigits: 1 })}
                          </span>
                        </div>
                      </td>
                      <td className="py-1.5 pr-2 text-[var(--text-secondary)]">
                        {aprPercent.toFixed(0)}%
                      </td>
                      <td className="py-1.5 pr-2 text-[var(--text-secondary)]">
                        {interestOwed.toFixed(4)}
                      </td>
                      <td className="py-1.5 pr-2">
                        <div className="flex items-center gap-1">
                          <div className="w-8 h-1 bg-[var(--obsidian)] rounded-full overflow-hidden">
                            <div 
                              className="h-full bg-[var(--gold)] transition-all"
                              style={{ width: `${repaidPercent}%` }}
                            />
                          </div>
                          <span className="text-[10px] text-[var(--text-muted)]">
                            {repaidPercent.toFixed(0)}%
                          </span>
                        </div>
                      </td>
                      <td className="py-1.5 pr-2">
                        <span className={`text-[10px] px-1 py-0.5 rounded ${
                          note.fullyRepaid 
                            ? 'bg-green-500/20 text-green-400' 
                            : 'bg-[var(--gold)]/20 text-[var(--gold)]'
                        }`}>
                          {note.fullyRepaid ? '✓' : '●'}
                        </span>
                      </td>
                      <td className="py-1.5">
                        <button
                          onClick={() => setTransferTokenId(note.tokenId)}
                          className="text-[10px] px-1.5 py-0.5 rounded border border-[var(--charcoal)] text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--charcoal)] transition-colors"
                        >
                          →
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </CardContent>

      {/* Transfer Modal */}
      {transferTokenId !== null && (
        <TransferModal
          isOpen={true}
          onClose={() => setTransferTokenId(null)}
          tokenId={transferTokenId}
          onSuccess={() => refetchBalance()}
        />
      )}
    </Card>
  );
}
