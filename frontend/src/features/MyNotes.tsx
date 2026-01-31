import { useState } from 'react';
import { useAccount, useReadContract, useReadContracts } from 'wagmi';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
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

interface NoteCardProps {
  note: NoteInfo;
  onTransfer: (tokenId: bigint) => void;
}

function NoteCard({ note, onTransfer }: NoteCardProps) {
  const principal = Number(formatUnits(note.principal, 18));
  const remainingPrincipal = Number(formatUnits(note.remainingPrincipal, 18));
  const interestOwed = Number(formatUnits(note.interestOwed, 18));
  const interestAccrued = Number(formatUnits(note.interestAccrued, 18));
  const totalRepaid = Number(formatUnits(note.totalRepaid, 18));
  const aprPercent = Number(note.aprBps) / 100;
  
  const repaidPercent = principal > 0 
    ? ((principal - remainingPrincipal) / principal) * 100 
    : 0;

  return (
    <div className="p-4 bg-[var(--charcoal)] rounded-lg border border-[var(--gold)]/20">
      <div className="flex justify-between items-start mb-3">
        <div>
          <span className="text-xs text-[var(--text-muted)]">Note #{note.tokenId.toString()}</span>
          <h4 className="text-lg font-semibold text-[var(--gold)]">
            {principal.toFixed(2)} USDT
          </h4>
        </div>
        <div className="text-right flex items-center gap-2">
          <span className={`text-xs px-2 py-1 rounded ${
            note.fullyRepaid 
              ? 'bg-green-500/20 text-green-400' 
              : 'bg-[var(--gold)]/20 text-[var(--gold)]'
          }`}>
            {note.fullyRepaid ? 'Completed' : 'Active'}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3 text-sm">
        <div>
          <span className="text-[var(--text-muted)]">Tranche</span>
          <p className="text-[var(--text-secondary)]">#{note.trancheId.toString()}</p>
        </div>
        <div>
          <span className="text-[var(--text-muted)]">APR</span>
          <p className="text-[var(--text-secondary)]">{aprPercent.toFixed(1)}%</p>
        </div>
        <div className="relative group">
          <span className="text-[var(--text-muted)] flex items-center gap-1">
            Interest Owed
            <span className="text-xs cursor-help" title="Interest Owed = Accrued + Current Period - Paid">ⓘ</span>
          </span>
          <p className="text-[var(--gold)]">{interestOwed.toFixed(4)} USDT</p>
          {interestAccrued > 0 && (
            <p className="text-xs text-[var(--text-muted)]">
              ({interestAccrued.toFixed(4)} accrued)
            </p>
          )}
        </div>
        <div>
          <span className="text-[var(--text-muted)]">Total Repaid</span>
          <p className="text-[var(--text-secondary)]">{totalRepaid.toFixed(2)} USDT</p>
        </div>
      </div>

      {!note.fullyRepaid && (
        <div className="mt-3">
          <div className="flex justify-between text-xs mb-1">
            <span className="text-[var(--text-muted)]">Principal Repaid</span>
            <span className="text-[var(--text-secondary)]">{repaidPercent.toFixed(1)}%</span>
          </div>
          <div className="h-2 bg-[var(--obsidian)] rounded-full overflow-hidden">
            <div 
              className="h-full bg-[var(--gold)] transition-all duration-300"
              style={{ width: `${repaidPercent}%` }}
            />
          </div>
        </div>
      )}

      {/* Action buttons - Repay is typically done by 3rd party apps or admin */}
      <div className="mt-4">
        <button
          onClick={() => onTransfer(note.tokenId)}
          className="w-full px-3 py-2 text-sm rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] hover:text-[var(--text-primary)] transition-colors"
        >
          Transfer
        </button>
      </div>
    </div>
  );
}

export function MyNotes() {
  const { address, isConnected } = useAccount();
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;
  const [transferTokenId, setTransferTokenId] = useState<bigint | null>(null);

  // Get balance of notes
  const { data: noteBalance, refetch: refetchBalance } = useReadContract({
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

  // Extract token IDs from results
  const tokenIds: bigint[] = tokenIdResults
    ?.map(result => result.status === 'success' ? result.result as bigint : null)
    .filter((id): id is bigint => id !== null) ?? [];

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
  const notes: NoteInfo[] = noteInfoResults
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
    .filter((note): note is NoteInfo => note !== null) ?? [];

  if (!isConnected) {
    return (
      <Card>
        <CardContent className="text-center py-8">
          <p className="text-[var(--text-muted)]">
            Connect your wallet to view your donation notes
          </p>
        </CardContent>
      </Card>
    );
  }

  if (!trancheAddress) {
    return (
      <Card>
        <CardContent className="text-center py-8">
          <p className="text-[var(--text-muted)]">
            Contract not deployed yet
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>My Donation Notes</CardTitle>
        <p className="text-sm text-[var(--text-muted)] mt-1">
          {noteCount} note{noteCount !== 1 ? 's' : ''} owned
        </p>
      </CardHeader>

      <CardContent>
        {isLoading ? (
          <div className="space-y-4">
            {[1, 2].map((i) => (
              <div key={i} className="p-4 bg-[var(--charcoal)] rounded-lg border border-[var(--gold)]/20 animate-pulse">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <div className="h-3 w-16 bg-[var(--obsidian)] rounded mb-2" />
                    <div className="h-5 w-24 bg-[var(--obsidian)] rounded" />
                  </div>
                  <div className="h-5 w-16 bg-[var(--obsidian)] rounded" />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="h-8 bg-[var(--obsidian)] rounded" />
                  <div className="h-8 bg-[var(--obsidian)] rounded" />
                  <div className="h-8 bg-[var(--obsidian)] rounded" />
                  <div className="h-8 bg-[var(--obsidian)] rounded" />
                </div>
              </div>
            ))}
          </div>
        ) : noteCount === 0 ? (
          <div className="text-center py-8">
            <p className="text-[var(--text-muted)] mb-2">
              You don't have any donation notes yet
            </p>
            <p className="text-sm text-[var(--text-muted)]">
              Contribute to a tranche to receive your first note
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {notes.map((note) => (
              <NoteCard 
                key={note.tokenId.toString()} 
                note={note} 
                onTransfer={setTransferTokenId}
              />
            ))}
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
