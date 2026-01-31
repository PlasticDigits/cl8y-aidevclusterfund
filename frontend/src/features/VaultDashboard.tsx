import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatUnits } from 'viem';
import { toast } from 'sonner';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { ADDRESSES } from '@/lib/config';
import { DonationMatchVaultABI } from '@/lib/abi/DonationMatchVault';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { ERC20ABI } from '@/lib/abi/erc20';

interface VaultNoteInfo {
  tokenId: bigint;
  trancheId: bigint;
  aprBps: bigint;
  interestOwed: bigint;
  principal: bigint;
  principalRepaid: bigint;
  remainingPrincipal: bigint;
  fullyRepaid: boolean;
}

export function VaultDashboard() {
  const { address, isConnected } = useAccount();
  const vaultAddress = ADDRESSES.DONATION_VAULT;
  const trancheAddress = ADDRESSES.DONATION_TRANCHE;
  const usdtAddress = ADDRESSES.USDT;

  const [repayTokenId, setRepayTokenId] = useState('');
  const [repayAmount, setRepayAmount] = useState('');

  // Check vault owner
  const { data: vaultOwner } = useReadContract({
    address: vaultAddress,
    abi: DonationMatchVaultABI,
    functionName: 'owner',
    query: { enabled: !!vaultAddress },
  });

  // Check if connected wallet is vault owner
  const isVaultOwner = isConnected && address && vaultOwner && 
    address.toLowerCase() === (vaultOwner as string).toLowerCase();

  // Get vault USDT balance
  const { data: vaultBalance, refetch: refetchBalance } = useReadContract({
    address: vaultAddress,
    abi: DonationMatchVaultABI,
    functionName: 'getBalance',
    query: { enabled: !!vaultAddress },
  });

  // Get vault's note balance
  const { data: noteBalance, refetch: refetchNoteBalance } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'balanceOf',
    args: vaultAddress ? [vaultAddress] : undefined,
    query: { enabled: !!vaultAddress && !!trancheAddress },
  });

  const noteCount = noteBalance ? Number(noteBalance) : 0;

  // Build contract calls for token IDs
  const tokenIdCalls = Array.from({ length: noteCount }, (_, index) => ({
    address: trancheAddress!,
    abi: DonationTrancheABI,
    functionName: 'tokenOfOwnerByIndex' as const,
    args: [vaultAddress!, BigInt(index)] as const,
  }));

  // Fetch all token IDs
  const { data: tokenIdResults } = useReadContracts({
    contracts: tokenIdCalls,
    query: { enabled: noteCount > 0 && !!vaultAddress && !!trancheAddress },
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
  const { data: noteInfoResults, refetch: refetchNoteInfo } = useReadContracts({
    contracts: noteInfoCalls,
    query: { enabled: tokenIds.length > 0 && !!trancheAddress },
  });

  // Parse note info results
  const vaultNotes: VaultNoteInfo[] = noteInfoResults
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
        remainingPrincipal: data[10],
        fullyRepaid: data[12],
      };
    })
    .filter((note): note is VaultNoteInfo => note !== null) ?? [];

  // Get USDT allowance for tranche from vault
  const { data: trancheAllowance } = useReadContract({
    address: usdtAddress,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: vaultAddress && trancheAddress ? [vaultAddress, trancheAddress] : undefined,
    query: { enabled: !!vaultAddress && !!trancheAddress && !!usdtAddress },
  });

  // Write contract hooks
  const { 
    writeContract: withdraw, 
    data: withdrawTxHash,
    isPending: isWithdrawPending,
    error: withdrawError,
  } = useWriteContract();

  const { 
    writeContract: approveUsdt, 
    data: approveTxHash,
    isPending: isApprovePending,
    error: approveError,
  } = useWriteContract();

  const { 
    writeContract: repayNote, 
    data: repayTxHash,
    isPending: isRepayPending,
    error: repayError,
  } = useWriteContract();

  // Transaction receipts
  const { isSuccess: withdrawSuccess } = useWaitForTransactionReceipt({ hash: withdrawTxHash });
  const { isSuccess: approveSuccess } = useWaitForTransactionReceipt({ hash: approveTxHash });
  const { isSuccess: repaySuccess } = useWaitForTransactionReceipt({ hash: repayTxHash });

  // Handle errors
  useEffect(() => {
    if (withdrawError) toast.error('Withdraw failed', { description: withdrawError.message.slice(0, 100) });
    if (approveError) toast.error('Approve failed', { description: approveError.message.slice(0, 100) });
    if (repayError) toast.error('Repay failed', { description: repayError.message.slice(0, 100) });
  }, [withdrawError, approveError, repayError]);

  // Handle success
  useEffect(() => {
    if (withdrawSuccess) {
      toast.success('Vault withdrawn successfully!');
      refetchBalance();
    }
  }, [withdrawSuccess, refetchBalance]);

  useEffect(() => {
    if (approveSuccess) {
      toast.success('Tranche approved for matching!');
      refetchBalance();
    }
  }, [approveSuccess, refetchBalance]);

  useEffect(() => {
    if (repaySuccess) {
      toast.success('Note repaid successfully!');
      refetchNoteInfo();
      refetchNoteBalance();
      setRepayTokenId('');
      setRepayAmount('');
    }
  }, [repaySuccess, refetchNoteInfo, refetchNoteBalance]);

  // Action handlers
  const handleWithdraw = () => {
    if (!vaultAddress) return;
    withdraw({
      address: vaultAddress,
      abi: DonationMatchVaultABI,
      functionName: 'withdraw',
    });
  };

  const handleApprove = () => {
    if (!vaultAddress || !trancheAddress) return;
    approveUsdt({
      address: vaultAddress,
      abi: DonationMatchVaultABI,
      functionName: 'approveUsdt',
      args: [trancheAddress, BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')],
    });
  };

  const handleRepayNote = () => {
    if (!trancheAddress || !repayTokenId || !repayAmount) return;
    
    const tokenId = BigInt(repayTokenId);
    const amount = BigInt(parseFloat(repayAmount) * 1e18);
    
    repayNote({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'repay',
      args: [tokenId, amount],
    });
  };

  // Don't render if not vault owner
  if (!isVaultOwner) {
    return null;
  }

  if (!vaultAddress || !trancheAddress) {
    return (
      <Card>
        <CardContent className="py-8 text-center text-[var(--text-muted)]">
          Contracts not deployed
        </CardContent>
      </Card>
    );
  }

  const balance = vaultBalance ? Number(formatUnits(vaultBalance as bigint, 18)) : 0;
  const allowance = trancheAllowance ? Number(formatUnits(trancheAllowance as bigint, 18)) : 0;
  const hasUnlimitedAllowance = allowance > 1e15;

  // Calculate total value of vault notes
  const totalNoteValue = vaultNotes.reduce((acc, note) => {
    return acc + Number(formatUnits(note.remainingPrincipal + note.interestOwed, 18));
  }, 0);

  const activeNotes = vaultNotes.filter(n => !n.fullyRepaid);

  return (
    <Card className="border-blue-500/30 bg-blue-500/5">
      <CardHeader>
        <CardTitle className="text-blue-400">Vault Dashboard</CardTitle>
        <p className="text-sm text-[var(--text-muted)]">
          Manage the matching vault (owner only)
        </p>
      </CardHeader>

      <CardContent className="space-y-6">
        {/* Vault Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-[var(--charcoal)] rounded-lg">
          <div>
            <p className="text-xs text-[var(--text-muted)]">USDT Balance</p>
            <p className="font-semibold text-[var(--gold)]">
              {balance.toLocaleString(undefined, { maximumFractionDigits: 2 })} USDT
            </p>
          </div>
          <div>
            <p className="text-xs text-[var(--text-muted)]">Notes Owned</p>
            <p className="font-semibold text-[var(--text-primary)]">
              {noteCount} notes
            </p>
          </div>
          <div>
            <p className="text-xs text-[var(--text-muted)]">Notes Value</p>
            <p className="font-semibold text-[var(--text-primary)]">
              {totalNoteValue.toLocaleString(undefined, { maximumFractionDigits: 2 })} USDT
            </p>
          </div>
          <div>
            <p className="text-xs text-[var(--text-muted)]">Tranche Approved</p>
            <p className={`font-semibold ${hasUnlimitedAllowance ? 'text-green-400' : 'text-yellow-400'}`}>
              {hasUnlimitedAllowance ? 'Unlimited' : `${allowance.toFixed(0)} USDT`}
            </p>
          </div>
        </div>

        {/* Actions */}
        <div className="space-y-4">
          <div className="flex flex-wrap gap-3">
            <button
              onClick={handleWithdraw}
              disabled={isWithdrawPending || balance === 0}
              className="px-4 py-2 rounded-lg bg-blue-500 text-white font-semibold hover:bg-blue-600 disabled:opacity-50 transition-colors"
            >
              {isWithdrawPending ? 'Withdrawing...' : 'Withdraw All USDT'}
            </button>
            
            <button
              onClick={handleApprove}
              disabled={isApprovePending || hasUnlimitedAllowance}
              className="px-4 py-2 rounded-lg border border-blue-500 text-blue-400 hover:bg-blue-500/10 disabled:opacity-50 transition-colors"
            >
              {isApprovePending ? 'Approving...' : hasUnlimitedAllowance ? 'Already Approved' : 'Approve Tranche'}
            </button>
          </div>
        </div>

        {/* Vault Notes */}
        {activeNotes.length > 0 && (
          <div className="space-y-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
              Vault Notes ({activeNotes.length} active)
            </h3>
            <div className="grid gap-3">
              {activeNotes.slice(0, 5).map((note) => (
                <div 
                  key={note.tokenId.toString()} 
                  className="p-3 bg-[var(--charcoal)] rounded-lg flex justify-between items-center"
                >
                  <div>
                    <span className="text-sm text-[var(--text-muted)]">
                      Note #{note.tokenId.toString()}
                    </span>
                    <p className="text-[var(--text-primary)]">
                      {Number(formatUnits(note.principal, 18)).toFixed(2)} USDT
                    </p>
                    <p className="text-xs text-[var(--gold)]">
                      Interest: {Number(formatUnits(note.interestOwed, 18)).toFixed(4)} USDT
                    </p>
                  </div>
                  <div className="text-right">
                    <span className="text-xs text-[var(--text-muted)]">
                      Tranche #{note.trancheId.toString()}
                    </span>
                    <p className="text-sm text-[var(--text-secondary)]">
                      {(Number(note.aprBps) / 100).toFixed(1)}% APR
                    </p>
                  </div>
                </div>
              ))}
              {activeNotes.length > 5 && (
                <p className="text-sm text-[var(--text-muted)] text-center">
                  +{activeNotes.length - 5} more notes
                </p>
              )}
            </div>
          </div>
        )}

        {/* Repay Note Section */}
        <div className="space-y-3 p-4 bg-[var(--charcoal)] rounded-lg">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
            Repay a Note
          </h3>
          <p className="text-xs text-[var(--text-muted)]">
            Anyone can repay any note. Payment goes to the note owner.
          </p>
          <div className="flex flex-wrap gap-3">
            <input
              type="number"
              placeholder="Note ID"
              value={repayTokenId}
              onChange={(e) => setRepayTokenId(e.target.value)}
              className="w-28 px-3 py-2 rounded-lg bg-[var(--obsidian)] border border-[var(--charcoal)] text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
            <input
              type="number"
              placeholder="Amount (USDT)"
              value={repayAmount}
              onChange={(e) => setRepayAmount(e.target.value)}
              className="flex-1 min-w-32 px-3 py-2 rounded-lg bg-[var(--obsidian)] border border-[var(--charcoal)] text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
            <button
              onClick={handleRepayNote}
              disabled={isRepayPending || !repayTokenId || !repayAmount}
              className="px-4 py-2 rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] disabled:opacity-50 transition-colors"
            >
              {isRepayPending ? 'Repaying...' : 'Repay'}
            </button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
