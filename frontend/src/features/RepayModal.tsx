import { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { toast } from 'sonner';
import { ADDRESSES } from '@/lib/config';
import { DonationTrancheABI } from '@/lib/abi/DonationTranche';
import { ERC20ABI } from '@/lib/abi/erc20';
import { parseContractError } from '@/lib/errorMessages';

interface NoteInfo {
  tokenId: bigint;
  owner: string;
  trancheId: bigint;
  aprBps: bigint;
  interestOwed: bigint;
  principal: bigint;
  principalRepaid: bigint;
  remainingPrincipal: bigint;
  fullyRepaid: boolean;
}

interface RepayModalProps {
  isOpen: boolean;
  onClose: () => void;
  tokenId: bigint;
  noteInfo?: NoteInfo;
  onSuccess?: () => void;
}

export function RepayModal({ isOpen, onClose, tokenId, noteInfo, onSuccess }: RepayModalProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState('');
  const [step, setStep] = useState<'input' | 'approve' | 'repay' | 'success'>('input');

  const trancheAddress = ADDRESSES.DONATION_TRANCHE;
  const usdtAddress = ADDRESSES.USDT;

  // Fetch note info if not provided
  const { data: fetchedNoteInfo } = useReadContract({
    address: trancheAddress,
    abi: DonationTrancheABI,
    functionName: 'getNoteInfo',
    args: [tokenId],
    query: { enabled: !!trancheAddress && !noteInfo },
  });

  // Parse fetched note info
  const note = useMemo(() => {
    if (noteInfo) return noteInfo;
    if (!fetchedNoteInfo) return null;
    
    const data = fetchedNoteInfo as readonly [
      string, bigint, bigint, bigint, bigint, bigint,
      bigint, bigint, bigint, bigint, bigint, bigint, boolean, bigint
    ];
    return {
      tokenId,
      owner: data[0],
      trancheId: data[1],
      aprBps: data[2],
      interestOwed: data[4],
      principal: data[6],
      principalRepaid: data[7],
      remainingPrincipal: data[10],
      fullyRepaid: data[12],
    };
  }, [noteInfo, fetchedNoteInfo, tokenId]);

  // Get user USDT balance
  const { data: usdtBalance } = useReadContract({
    address: usdtAddress,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!usdtAddress },
  });

  // Get user USDT allowance for tranche
  const { data: usdtAllowance, refetch: refetchAllowance } = useReadContract({
    address: usdtAddress,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: address && trancheAddress ? [address, trancheAddress] : undefined,
    query: { enabled: !!address && !!trancheAddress && !!usdtAddress },
  });

  // Write contract hooks - Approve
  const { 
    writeContract: approve, 
    data: approveTxHash,
    isPending: isApprovePending,
    error: approveError,
    reset: resetApprove,
  } = useWriteContract();

  // Write contract hooks - Repay
  const { 
    writeContract: repay, 
    data: repayTxHash,
    isPending: isRepayPending,
    error: repayError,
    reset: resetRepay,
  } = useWriteContract();

  // Transaction receipts
  const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess } = 
    useWaitForTransactionReceipt({ hash: approveTxHash });
  
  const { isLoading: isRepayConfirming, isSuccess: isRepaySuccess } = 
    useWaitForTransactionReceipt({ hash: repayTxHash });

  // Handle errors
  useEffect(() => {
    if (approveError) {
      toast.error('Approval failed', { description: parseContractError(approveError) });
      setStep('input');
    }
    if (repayError) {
      toast.error('Repayment failed', { description: parseContractError(repayError) });
      setStep('input');
    }
  }, [approveError, repayError]);

  // Define handleClose early with useCallback
  const handleClose = useCallback(() => {
    setAmount('');
    setStep('input');
    resetApprove();
    resetRepay();
    onClose();
  }, [resetApprove, resetRepay, onClose]);

  // Track previous success states
  const prevApproveSuccess = useRef(false);
  const prevRepaySuccess = useRef(false);

  // Stable approve success handler - need to use ref for executeRepay since it's defined later
  const executeRepayRef = useRef<() => void>();

  // Handle approve success
  useEffect(() => {
    if (isApproveSuccess && !prevApproveSuccess.current) {
      refetchAllowance();
      setStep('repay');
      executeRepayRef.current?.();
    }
    prevApproveSuccess.current = isApproveSuccess;
  }, [isApproveSuccess, refetchAllowance]);

  // Stable repay success handler
  const handleRepaySuccess = useCallback(() => {
    setStep('success');
    toast.success('Repayment successful!', {
      description: `Repaid ${amount} USDT on Note #${tokenId.toString()}`,
    });
    onSuccess?.();
    setTimeout(() => {
      handleClose();
    }, 1500);
  }, [amount, tokenId, onSuccess, handleClose]);

  // Handle repay success
  useEffect(() => {
    if (isRepaySuccess && !prevRepaySuccess.current) {
      handleRepaySuccess();
    }
    prevRepaySuccess.current = isRepaySuccess;
  }, [isRepaySuccess, handleRepaySuccess]);

  const amountWei = useMemo(() => {
    if (!amount || isNaN(parseFloat(amount))) return BigInt(0);
    try {
      return parseUnits(amount, 18);
    } catch {
      return BigInt(0);
    }
  }, [amount]);

  const needsApproval = useMemo(() => {
    if (!usdtAllowance || amountWei === BigInt(0)) return true;
    return (usdtAllowance as bigint) < amountWei;
  }, [usdtAllowance, amountWei]);

  const hasInsufficientBalance = useMemo(() => {
    if (!usdtBalance || amountWei === BigInt(0)) return false;
    return (usdtBalance as bigint) < amountWei;
  }, [usdtBalance, amountWei]);

  const executeApprove = () => {
    if (!usdtAddress || !trancheAddress) return;
    setStep('approve');
    approve({
      address: usdtAddress,
      abi: ERC20ABI,
      functionName: 'approve',
      args: [trancheAddress, amountWei],
    });
  };

  const executeRepay = useCallback(() => {
    if (!trancheAddress) return;
    setStep('repay');
    repay({
      address: trancheAddress,
      abi: DonationTrancheABI,
      functionName: 'repay',
      args: [tokenId, amountWei],
    });
  }, [trancheAddress, repay, tokenId, amountWei]);

  // Keep ref updated for use in approve success effect
  executeRepayRef.current = executeRepay;

  const handleRepay = () => {
    if (needsApproval) {
      executeApprove();
    } else {
      executeRepay();
    }
  };

  const setMaxAmount = () => {
    if (!note) return;
    const totalOwed = note.interestOwed + note.remainingPrincipal;
    setAmount(formatUnits(totalOwed, 18));
  };

  const setInterestOnly = () => {
    if (!note || note.interestOwed === BigInt(0)) return;
    setAmount(formatUnits(note.interestOwed, 18));
  };

  if (!isOpen) return null;

  const isLoading = isApprovePending || isApproveConfirming || isRepayPending || isRepayConfirming;
  const isValidAmount = amountWei > BigInt(0) && !hasInsufficientBalance;

  const interestOwed = note ? Number(formatUnits(note.interestOwed, 18)) : 0;
  const remainingPrincipal = note ? Number(formatUnits(note.remainingPrincipal, 18)) : 0;
  const totalOwed = interestOwed + remainingPrincipal;
  const repayAmountNum = parseFloat(amount) || 0;

  // Calculate payment breakdown preview
  const interestPortion = Math.min(repayAmountNum, interestOwed);
  const principalPortion = Math.max(0, repayAmountNum - interestOwed);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        onClick={!isLoading ? handleClose : undefined}
      />

      {/* Modal */}
      <div className="relative z-10 w-full max-w-md mx-4 bg-[var(--obsidian)] border border-[var(--charcoal)] rounded-xl p-6 shadow-2xl">
        <h2 className="text-xl font-bold text-[var(--text-primary)] mb-2">
          Repay Note #{tokenId.toString()}
        </h2>
        <p className="text-sm text-[var(--text-muted)] mb-6">
          Anyone can repay any note. Payment goes to the current owner.
        </p>

        {note && (
          <>
            {/* Note Info */}
            <div className="mb-6 p-4 bg-[var(--charcoal)] rounded-lg space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-muted)]">Note Owner</span>
                <span className="text-[var(--text-secondary)] font-mono text-xs">
                  {note.owner.slice(0, 6)}...{note.owner.slice(-4)}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-muted)]">Interest Owed</span>
                <span className="text-[var(--gold)]">{interestOwed.toFixed(4)} USDT</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-muted)]">Principal Remaining</span>
                <span className="text-[var(--text-secondary)]">{remainingPrincipal.toFixed(2)} USDT</span>
              </div>
              <div className="flex justify-between text-sm font-semibold border-t border-[var(--obsidian)] pt-2">
                <span className="text-[var(--text-primary)]">Total Owed</span>
                <span className="text-[var(--text-primary)]">{totalOwed.toFixed(4)} USDT</span>
              </div>
            </div>

            {/* Amount Input */}
            <div className="mb-4">
              <label className="block text-sm text-[var(--text-secondary)] mb-2">
                Amount to Repay (USDT)
              </label>
              <div className="relative">
                <input
                  type="number"
                  placeholder="0.00"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  disabled={isLoading}
                  step="0.01"
                  min="0"
                  className={`
                    w-full px-4 py-3 rounded-lg 
                    bg-[var(--charcoal)] border 
                    text-[var(--text-primary)] placeholder:text-[var(--text-muted)]
                    focus:outline-none focus:ring-2 focus:ring-[var(--gold)]/50
                    disabled:opacity-50
                    ${hasInsufficientBalance ? 'border-red-500' : 'border-[var(--charcoal)]'}
                  `}
                />
              </div>
              {hasInsufficientBalance && (
                <p className="text-red-400 text-xs mt-2">
                  Insufficient USDT balance
                </p>
              )}
            </div>

            {/* Quick Actions */}
            <div className="flex gap-2 mb-4">
              <button
                onClick={setInterestOnly}
                disabled={isLoading || interestOwed === 0}
                className="flex-1 px-3 py-2 text-sm rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] disabled:opacity-50 transition-colors"
              >
                Interest ({interestOwed.toFixed(2)})
              </button>
              <button
                onClick={setMaxAmount}
                disabled={isLoading}
                className="flex-1 px-3 py-2 text-sm rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] disabled:opacity-50 transition-colors"
              >
                Full ({totalOwed.toFixed(2)})
              </button>
            </div>

            {/* Payment Breakdown Preview */}
            {repayAmountNum > 0 && (
              <div className="mb-6 p-3 bg-[var(--charcoal)]/50 rounded-lg text-sm">
                <p className="text-[var(--text-muted)] mb-1">Payment Breakdown:</p>
                <p className="text-xs text-[var(--text-muted)] mb-2 italic">
                  Interest is always paid before principal
                </p>
                <div className="flex justify-between">
                  <span className="text-[var(--gold)]">Interest</span>
                  <span className="text-[var(--gold)]">{interestPortion.toFixed(4)} USDT</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-secondary)]">Principal</span>
                  <span className="text-[var(--text-secondary)]">{principalPortion.toFixed(4)} USDT</span>
                </div>
              </div>
            )}

            {/* Actions */}
            <div className="flex gap-3">
              <button
                onClick={handleClose}
                disabled={isLoading}
                className="flex-1 px-4 py-3 rounded-lg border border-[var(--charcoal)] text-[var(--text-secondary)] hover:bg-[var(--charcoal)] transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleRepay}
                disabled={!isValidAmount || isLoading || note.fullyRepaid}
                className="flex-1 px-4 py-3 rounded-lg bg-[var(--gold)] text-[var(--black)] font-semibold hover:bg-[var(--gold)]/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {step === 'approve' && isApprovePending ? 'Confirm Approval...' 
                  : step === 'approve' && isApproveConfirming ? 'Approving...'
                  : step === 'repay' && isRepayPending ? 'Confirm Repay...'
                  : step === 'repay' && isRepayConfirming ? 'Repaying...'
                  : step === 'success' ? 'Success!'
                  : needsApproval ? 'Approve & Repay'
                  : 'Repay'}
              </button>
            </div>
          </>
        )}

        {!note && (
          <div className="text-center py-8 text-[var(--text-muted)]">
            Loading note info...
          </div>
        )}
      </div>
    </div>
  );
}
